import logging
import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI, BackgroundTasks, Request, HTTPException
from fastapi.responses import JSONResponse
from models.schemas import AlertWebhook, Alert, AnalysisResult
from services.analyzer import AlertAnalyzer
from services.notifier import NotificationService
from config import settings

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize services
analyzer = AlertAnalyzer()
notifier = NotificationService()

# Alert queue for processing
alert_queue: asyncio.Queue = asyncio.Queue()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifecycle manager for the application"""
    # Startup
    logger.info("Starting AIOps Alert Processor")
    logger.info(f"Prometheus URL: {settings.prometheus_url}")
    logger.info(f"Loki URL: {settings.loki_url}")
    logger.info(f"DeepSeek Model: {settings.deepseek_model}")
    logger.info(f"Time Window: {settings.time_window_minutes} minutes")
    
    # Start background alert processor
    processor_task = asyncio.create_task(process_alert_queue())
    
    yield
    
    # Shutdown
    logger.info("Shutting down AIOps Alert Processor")
    processor_task.cancel()
    try:
        await processor_task
    except asyncio.CancelledError:
        pass


# Create FastAPI app
app = FastAPI(
    title="AIOps Alert Processor",
    description="AI-powered alert analysis and resolution system",
    version="1.0.0",
    lifespan=lifespan
)


@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "service": "AIOps Alert Processor",
        "status": "running",
        "version": "1.0.0"
    }


@app.get("/health")
async def health_check():
    """Detailed health check"""
    return {
        "status": "healthy",
        "services": {
            "prometheus": settings.prometheus_url,
            "loki": settings.loki_url,
            "llm_model": settings.deepseek_model
        },
        "queue_size": alert_queue.qsize()
    }


@app.post("/webhook/alerts")
async def receive_alerts(webhook: AlertWebhook, background_tasks: BackgroundTasks):
    """
    Receive alerts from AlertManager
    
    This endpoint receives webhook notifications from AlertManager and
    queues them for analysis.
    """
    logger.info(f"Received webhook from AlertManager: {webhook.receiver}")
    logger.info(f"Status: {webhook.status}, Alerts: {len(webhook.alerts)}")
    
    # Process only firing alerts
    firing_alerts = [alert for alert in webhook.alerts if alert.status == "firing"]
    
    if not firing_alerts:
        logger.info("No firing alerts to process")
        return {"status": "ok", "message": "No firing alerts", "processed": 0}
    
    # Add alerts to the queue
    for alert in firing_alerts:
        await alert_queue.put(alert)
        logger.info(f"Queued alert: {alert.labels.get('alertname', 'Unknown')}")
    
    return {
        "status": "ok",
        "message": f"Queued {len(firing_alerts)} alerts for analysis",
        "processed": len(firing_alerts),
        "queue_size": alert_queue.qsize()
    }


@app.post("/analyze")
async def analyze_single_alert(alert: Alert):
    """
    Manually trigger analysis for a single alert
    
    This endpoint allows manual submission of alerts for analysis,
    useful for testing or manual analysis requests.
    """
    logger.info(f"Manual analysis request for alert: {alert.labels.get('alertname', 'Unknown')}")
    
    try:
        # Analyze the alert
        result = await analyzer.analyze_alert(alert)
        
        if not result:
            raise HTTPException(status_code=500, detail="Analysis failed")
        
        # Send notification
        alert_context = {
            "instance": alert.labels.get("instance"),
            "generator_url": alert.generatorURL
        }
        await notifier.send_analysis(result, alert_context)
        
        return result
        
    except Exception as e:
        logger.error(f"Error analyzing alert: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/queue/status")
async def queue_status():
    """Get the current status of the alert queue"""
    return {
        "queue_size": alert_queue.qsize(),
        "status": "processing" if not alert_queue.empty() else "idle"
    }


async def process_alert_queue():
    """
    Background task that processes alerts from the queue
    
    This runs continuously and processes alerts one by one,
    ensuring sequential analysis with proper error handling.
    """
    logger.info("Alert queue processor started")
    
    while True:
        try:
            # Wait for an alert from the queue
            alert = await alert_queue.get()
            
            logger.info(f"Processing alert from queue: {alert.labels.get('alertname', 'Unknown')}")
            
            try:
                # Analyze the alert
                result = await analyzer.analyze_alert(alert)
                
                if result:
                    # Send notification
                    alert_context = {
                        "instance": alert.labels.get("instance"),
                        "generator_url": alert.generatorURL
                    }
                    notification_sent = await notifier.send_analysis(result, alert_context)
                    
                    if notification_sent:
                        logger.info(f"Successfully analyzed and notified for: {result.alert_name}")
                    else:
                        logger.warning(f"Analysis completed but notification failed for: {result.alert_name}")
                else:
                    logger.error(f"Analysis failed for alert: {alert.labels.get('alertname', 'Unknown')}")
                    
            except Exception as e:
                logger.error(f"Error processing alert: {e}", exc_info=True)
            
            finally:
                # Mark task as done
                alert_queue.task_done()
                
        except asyncio.CancelledError:
            logger.info("Alert queue processor cancelled")
            break
        except Exception as e:
            logger.error(f"Unexpected error in queue processor: {e}", exc_info=True)
            await asyncio.sleep(5)  # Wait before retrying


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global exception handler"""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal server error",
            "message": str(exc)
        }
    )


if __name__ == "__main__":
    import uvicorn
    
    uvicorn.run(
        "app:app",
        host=settings.api_host,
        port=settings.api_port,
        reload=False,
        log_level="info"
    )


