# Guía de instalación detallada en AWS (ECR + ECS Fargate) — PoC Chatbot Financiero

Este documento describe los pasos detallados para desplegar el PoC del chatbot financiero en AWS usando ECR y ECS (Fargate). Incluye creación de repositorio ECR, construcción y push de imagen Docker, creación de Task Definition, Service en ECS Fargate, configuración de ALB y ACM para TLS, y seguridad (Secrets Manager / SSM).

IMPORTANTE: Ejecuta estos pasos con una cuenta que tenga permisos para ECR, ECS, IAM, CloudWatch, ELB/ALB, ACM y SSM/Secrets Manager. Ajusta las regiones, ARNs y nombres a tu organización.

Contenido
- Requisitos previos
- Variables y nombres sugeridos
- Paso 1: Preparar el código y el entorno local
- Paso 2: Construir y pushear la imagen a ECR (script incluido)
- Paso 3: Crear roles IAM necesarios
- Paso 4: Subir secretos a SSM / Secrets Manager
- Paso 5: Editar y registrar la Task Definition en ECS
- Paso 6: Crear Cluster y Service en ECS (Fargate) y asociar ALB
- Paso 7: Configurar ALB y ACM (TLS)
- Paso 8: Probar y validar despliegue
- CI/CD con GitHub Actions
- Troubleshooting y comandos útiles

Requisitos previos
- AWS CLI v2 instalado y configurado (aws configure)
- Docker instalado (para build local)
- Cuenta AWS con permisos: ECR, ECS, IAM, CloudWatch, ELB/ALB, ACM, SSM/Secrets Manager
- Dominio público si quieres TLS real (ACM)

Variables y nombres sugeridos (ajusta a tu entorno)
- AWS_REGION=us-east-1
- ECR_REPOSITORY_NAME=poc-chatbot-financiero
- ECS_CLUSTER_NAME=poc-chatbot-cluster
- ECS_SERVICE_NAME=poc-chatbot-service
- ECS_TASK_FAMILY=poc-chatbot-task
- SSM parameter names:
  - /poc-chatbot/OPENAI_API_KEY
  - /poc-chatbot/ADMIN_TOKEN

Paso 1 — Preparar el código y entorno local
1. Clona la rama con el PoC (rama feature/poc-chatbot):
   git clone git@github.com:GersainAguilarPardo/ChatBot.git
   cd ChatBot
   git checkout feature/poc-chatbot

2. Copia el ejemplo de variables y edítalo:
   cp .env.example .env
   # Edita .env y coloca PROVIDER (openai o azure), OPENAI_API_KEY o AZURE_* y ADMIN_TOKEN

3. Probar localmente:
   npm install
   npm start
   # En otro terminal o navegador:
   http://localhost:3000  # UI usuario
   http://localhost:3000/agent.html  # Panel agente

Paso 2 — Construir y pushear la imagen a ECR
Opción A — Usar script incluido (recomendado): scripts/create-ecr-and-push.sh
1. Asegúrate de exportar la región y (opcional) el nombre del repo:
   export AWS_REGION=us-east-1
   export ECR_REPOSITORY_NAME=poc-chatbot-financiero

2. Ejecuta el script (requiere AWS CLI autenticado):
   chmod +x scripts/create-ecr-and-push.sh
   ./scripts/create-ecr-and-push.sh

El script: crea el repo si no existe, se loguea a ECR, construye la imagen y la pushea. Al finalizar imprime la IMAGE URI (ej: 123456789012.dkr.ecr.us-east-1.amazonaws.com/poc-chatbot-financiero:abcd1234).

Opción B — Manual (pasos):
  aws ecr create-repository --repository-name $ECR_REPOSITORY_NAME --region $AWS_REGION
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region $AWS_REGION)
  ECR_URI="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_NAME"
  aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
  docker build -t poc-chatbot-financiero:latest .
  docker tag poc-chatbot-financiero:latest "$ECR_URI:latest"
  docker push "$ECR_URI:latest"
Paso 3 — Crear roles IAM necesarios
1. Execution role (ECS Task Execution Role):
   - Nombre sugerido: ecsTaskExecutionRole-poc-chatbot
   - Policy a adjuntar: AmazonECSTaskExecutionRolePolicy
   - Purpose: permite a ECS hacer pull de ECR, escribir logs en CloudWatch y usar secretos.

2. Task role (opcional según necesidades):
   - Nombre sugerido: ecsTaskRole-poc-chatbot
   - Propósito: conceder permisos adicionales dentro de la tarea (por ejemplo, acceder a SSM/Secrets Manager si necesitas que la app los lea vía IAM en lugar de pasarlos como secrets).

Paso 4 — Subir secretos a SSM Parameter Store (SecureString) o Secrets Manager
Recomiendo SSM Parameter Store como ejemplo:
  aws ssm put-parameter --name "/poc-chatbot/OPENAI_API_KEY" --value "sk-..." --type "SecureString" --region $AWS_REGION
  aws ssm put-parameter --name "/poc-chatbot/ADMIN_TOKEN" --value "tu_admin_token_seguro" --type "SecureString" --region $AWS_REGION
Toma nota del ARN de cada parámetro (lo usarás en task-definition.json, campo secrets.valueFrom).
Paso 5 — Editar ecs/task-definition.json y registrar la Task Definition
1. Abre ecs/task-definition.json y reemplaza:  
   - "<TASK_FAMILY>" → $ECS_TASK_FAMILY
   - "<ECS_TASK_EXECUTION_ROLE_ARN>" → ARN del execution role (ecsTaskExecutionRole-poc-chatbot)
   - "<ECS_TASK_ROLE_ARN>" → ARN del task role (si aplica)
   - "<IMAGE_URI>" → URI de la imagen en ECR (ej: 123456789012.dkr.ecr.us-east-1.amazonaws.com/poc-chatbot-financiero:abcd1234)
   - "<arn:aws:ssm:region:account-id:parameter/OPENAI_API_KEY>" → ARN o el formato aceptado por valueFrom para SSM (ej: arn:aws:ssm:us-east-1:123456789012:parameter/poc-chatbot/OPENAI_API_KEY)
   - "<arn:aws:ssm:region:account-id:parameter/ADMIN_TOKEN>" → ARN para ADMIN_TOKEN
   - "<AWS_REGION>" → tu región (ej: us-east-1)

2. Registrar la task definition (CLI):
  aws ecs register-task-definition --cli-input-json file://ecs/task-definition.json
Paso 6 — Crear ECS Cluster y Service (Fargate) y asociar ALB
1. Crear cluster (si no existe):
  aws ecs create-cluster --cluster-name $ECS_CLUSTER_NAME
2. Crear Target Group y ALB (consola o AWS CLI) - ejemplo con consola recomendado para configuraciones VPC/subnets.

3. Crear Service (ECS Fargate) en la consola ECS (o con CLI) y vincular al Target Group del ALB:
  - Tipo de lanzamiento: FARGATE
  - Subnets: seleccionar subnets privadas (y públicas para ALB) según topología
  - Security Groups: permitir tráfico desde ALB al puerto 3000 (puerto del container)
  - Configurar health check: path /health, protocolo HTTP, puerto 3000

Paso 7 — Configurar ALB y ACM (TLS)
1. Crear o solicitar certificado en ACM para tu dominio (ej: api.coztyc.com).
2. Crear Application Load Balancer en la VPC (subnets públicas), y un Listener HTTPS 443 que use el cert de ACM y haga forward al Target Group creado para ECS.
3. Opcional: listener HTTP 80 que redirija a HTTPS.

Paso 8 — Probar y validar
1. Verificar que las tareas se inician y estén en RUNNING en ECS, y que pasen healthchecks (Target Group > Health checks).
2. Abrir la URL del ALB (o dominio asociado) y probar:  
   https://<tu-dominio>/ -> Debe mostrar la UI del chat (index.html)
   https://<tu-dominio>/agent.html -> Panel de agente
3. Probar conversación: envía una pregunta general (ej: "¿Cómo solicito una tarjeta?") y verifica que el bot responde.

CI/CD con GitHub Actions
- El repo incluye .github/workflows/deploy-to-aws.yml que:
  1) hace build de la imagen, 2) se loguea a ECR, 3) push de la imagen a ECR, 4) renderiza la task-definition con la IMAGE_URI y 5) despliega la task definition actualizada al servicio ECS.

Se requieren los siguientes GitHub secrets configurados en tu repo (Settings > Secrets > Actions):
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY
- AWS_REGION
- ECR_REPOSITORY (URI base del repo ECR, ej: 123456789012.dkr.ecr.us-east-1.amazonaws.com/poc-chatbot-financiero)
- ECS_CLUSTER_NAME
- ECS_SERVICE_NAME
- ECS_TASK_FAMILY

Además, guarda los secretos de la aplicación (OPENAI_API_KEY, ADMIN_TOKEN) en SSM o Secrets Manager y referencia sus ARNs desde ecs/task-definition.json.

Troubleshooting y comandos útiles
- Ver logs de la tarea en CloudWatch (group: /ecs/poc-chatbot-financiero)
- Ver eventos del servicio ECS en la consola de ECS (Service events)
- Si la tarea no inicia: revisar role permissions, network configuration (subnets/SG), y si la imagen está accesible en ECR (verify IMAGE URI)
- Comandos rápidos:
  aws ecs describe-services --cluster $ECS_CLUSTER_NAME --services $ECS_SERVICE_NAME --region $AWS_REGION
  aws ecs list-tasks --cluster $ECS_CLUSTER_NAME --service-name $ECS_SERVICE_NAME --region $AWS_REGION
  aws ecs describe-tasks --cluster $ECS_CLUSTER_NAME --tasks <task-ids> --region $AWS_REGION
  aws logs tail /ecs/poc-chatbot-financiero --since 1h --region $AWS_REGION

Seguridad y Production hardening (recomendaciones)
- No exponer ADMIN_TOKEN: sustituir por SSO/OAuth y roles RBAC para agentes.
- Mover claves a AWS Secrets Manager con rotación automática si es posible.
- Implementar WAF frente al ALB para bloquear tráfico malicioso y proteger endpoints.
- Reemplazar storage en memoria por RDS/DynamoDB y cifrar datos en reposo.
- Revisar y firmar por Compliance todos los textos regulatorios y plantillas de respuesta (tasas, CAT, condiciones).

Backup y rollbacks
- Versiona la task-definition en ECS y usa versiones para rollback rápido (aws ecs register-task-definition con la misma family genera revision numbers).
- Mantén tags de imagen en ECR (por commit SHA) para poder desplegar versiones específicas.

Anexos
- scripts/create-ecr-and-push.sh (helper para crear ECR y push)
- ecs/task-definition.json (plantilla con placeholders para IMAGE_URI y ARNs de secretos)
- .github/workflows/deploy-to-aws.yml (workflow para CI/CD)

Si quieres, puedo además generar:
- Plantilla Terraform mínima para crear ECR + ECS + ALB + IAM roles (si me das region y account-id).
- Automatizar que el workflow suba la imagen y actualice el service con variables concretas.

Fin del manual
