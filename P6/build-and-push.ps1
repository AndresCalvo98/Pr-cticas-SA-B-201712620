$Registry = "acrsap6andres.azurecr.io"

Write-Host "Iniciando sesión en Azure Container Registry..." -ForegroundColor Cyan
az acr login --name acrsap6andres

Write-Host "`nCompilando y subiendo API Gateway..." -ForegroundColor Yellow
docker build -t $Registry/api-gateway:latest ./src/api-gateway
docker push $Registry/api-gateway:latest

Write-Host "`nCompilando y subiendo Auth Service..." -ForegroundColor Yellow
docker build -t $Registry/auth-service:latest ./src/auth-service
docker push $Registry/auth-service:latest

Write-Host "`nCompilando y subiendo Transaction Service..." -ForegroundColor Yellow
docker build -t $Registry/transaction-service:latest ./src/transaction-service
docker push $Registry/transaction-service:latest

Write-Host "`nCompilando y subiendo Approval Service..." -ForegroundColor Yellow
docker build -t $Registry/approval-service:latest ./src/approval-service
docker push $Registry/approval-service:latest

Write-Host "`nCompilando y subiendo Notification Service..." -ForegroundColor Yellow
docker build -t $Registry/notification-service:latest ./src/notification-service
docker push $Registry/notification-service:latest

Write-Host "`nCompilando y subiendo CronJob Insert DB..." -ForegroundColor Yellow
docker build -t $Registry/cronjob-insert-db:latest ./src/cronjobs/cronjob1
docker push $Registry/cronjob-insert-db:latest

Write-Host "`nCompilando y subiendo CronJob Summary Broker..." -ForegroundColor Yellow
docker build -t $Registry/cronjob-summary-broker:latest ./src/cronjobs/cronjob2
docker push $Registry/cronjob-summary-broker:latest

Write-Host "`n¡Todas las imágenes han sido publicadas exitosamente en Azure!" -ForegroundColor Green
