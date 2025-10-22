```markdown
# PoC Chatbot Financiero — Coztyc (rama: feature/poc-chatbot)

Este repositorio contiene un PoC (prueba de concepto) de un chatbot conversacional en español orientado a una aplicación financiera (tarjeta de crédito, control de gastos y solicitudes de crédito). La UI está alineada visualmente con la identidad de Coztyc y el backend incluye guardrails para evitar divulgación de saldos o datos sensibles.

Índice
- Resumen
- Contenido del repositorio
- Requisitos
- Instalación y ejecución rápida (local)
- Ejecutar con Docker / docker-compose
- Variables de entorno (.env)
- Panel de agente
- Cómo editar la FAQ
- Despliegue en AWS (resumen)
- CI/CD con GitHub Actions
- Buenas prácticas de seguridad
- Troubleshooting rápido
- Contribuir

Resumen
- Respuestas en español (es-MX) con tono humano.
- Rechazo automático a consultas sensibles (saldos, CLABE, CVV, OTP, contraseñas).
- Panel de agente en tiempo real (Socket.IO): un humano puede tomar conversaciones y responder.
- Quick replies y mensajes enriquecidos en la UI.
- Soporta OpenAI y Azure OpenAI (configurable).
- Embeddings para búsqueda semántica en la FAQ.

Contenido del repositorio
- server.js — Backend Node.js (Express + Socket.IO), embeddings + LLM (configurable), reglas de rechazo.
- faq.yml — Base de conocimiento (FAQ) inicial.
- public/
  - index.html — UI usuario (chat).
  - chat.js — Lógica cliente (web).
  - agent.html — Panel de agente.
  - agent.js — Lógica del panel de agente.
- Dockerfile, docker-compose.yml — Contenerización y orquestación local.
- .env.example — Variables de entorno de ejemplo.
- .github/workflows/deploy-to-aws.yml — CI/CD (ECR + ECS).
- ecs/task-definition.json — Plantilla de Task Definition.
- scripts/ — Helpers (create-ecr-and-push, create-zip).
- README_INSTALL_AWS.md — Manual detallado para despliegue en AWS.

Requisitos
- Node.js 18+ o Docker
- npm
- (Para LLM) clave de OpenAI o Azure OpenAI
- (Para despliegue) Cuenta AWS con permisos ECR/ECS/IAM/ALB/ACM/SSM

Instalación y ejecución rápida (local)
1. Clona y cambia a la rama PoC:
   git clone git@github.com:GersainAguilarPardo/ChatBot.git
   cd ChatBot
   git fetch origin
   git checkout feature/poc-chatbot

2. Copia el ejemplo de variables:
   cp .env.example .env
   Edita `.env` y añade tus claves:
   - Si usas OpenAI: PROVIDER=openai y OPENAI_API_KEY=sk-...
   - Si usas Azure: PROVIDER=azure y configurar AZURE_*.
   - ADMIN_TOKEN: token para el panel de agente (PoC).

3. Instala dependencias:
   npm install

4. Ejecuta:
   npm start
   - UI usuario: http://localhost:3000
   - Panel agente: http://localhost:3000/agent.html

Ejecutar con Docker (local)
- Build:
  docker build -t poc-chatbot-financiero:local .
- Run:
  docker run -d --env-file .env -p 3000:3000 --name poc-chatbot poc-chatbot-financiero:local
- Stop + remove:
  docker stop poc-chatbot && docker rm poc-chatbot

Con docker-compose
- Levantar:
  docker-compose up -d --build
- Ver logs:
  docker-compose logs -f

Variables de entorno (.env)
- PROVIDER=openai | azure
- OPENAI_API_KEY (si PROVIDER=openai)
- AZURE_OPENAI_ENDPOINT, AZURE_OPENAI_KEY, AZURE_OPENAI_DEPLOYMENT (si PROVIDER=azure)
- ADMIN_TOKEN=token_fuerte_para_poc
- PORT=3000

Panel de agente (uso básico)
- Abrir /agent.html y conectar con el ADMIN_TOKEN (PoC).
- Verás conversaciones en tiempo real; al hacer clic en una conversación la "tomas" (claim) y puedes enviar respuestas.
- En producción: reemplazar ADMIN_TOKEN por SSO/OAuth y RBAC.

Editar y actualizar la FAQ
- Endpoint PoC: POST /v1/admin/faq
  - Header: Authorization: Bearer <ADMIN_TOKEN>
  - Body: JSON { "faqs": [...] } o YAML en el body.
- En este PoC la actualización reindexa embeddings en memoria. En producción usa un sistema con control de versiones y vector DB.

Despliegue en AWS (resumen)
- Flujo: Build Docker → Push a ECR → Register Task Definition → Deploy Service (ECS Fargate) → Asociar ALB con ACM para TLS.
- Guarda OPENAI_API_KEY y ADMIN_TOKEN en SSM Parameter Store (SecureString) o Secrets Manager y referencia sus ARNs en ecs/task-definition.json.
- Revisa README_INSTALL_AWS.md para pasos detallados.

CI/CD (GitHub Actions)
- .github/workflows/deploy-to-aws.yml incluido: build → push a ECR → render task def → deploy a ECS.
- Requiere configurar estos Secrets en el repo:
  - AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION
  - ECR_REPOSITORY, ECS_CLUSTER_NAME, ECS_SERVICE_NAME, ECS_TASK_FAMILY

Buenas prácticas (producción)
- No usar ADMIN_TOKEN hard-coded: implementar SSO/OAuth con rol y RBAC.
- Guardar secretos en Secret Manager o SSM SecureString.
- No permitir operaciones sensibles por chat; redirigir a canales autenticados.
- Persistir conversaciones en DB (RDS/DynamoDB) y usar vector DB para la KB.
- Habilitar TLS y WAF frente al ALB.

Troubleshooting rápido
- Si el bot no responde:
  - Revisa logs del servidor (local) o CloudWatch (AWS).
  - Comprueba que la variable OPENAI_API_KEY es válida y que PROVIDER está bien configurado.
- Errores en embeddings/LLM:
  - Revisa límites y cuotas de la cuenta LLM.
- CI/CD falla:
  - Verifica que los Secrets en GitHub son correctos y que la cuenta AWS asociada tiene permisos ECR/ECS.

Contribuir
- Añadir nuevas entradas a `faq.yml` o usar /v1/admin/faq.
- Para UI: editar los archivos en `public/`.
- Para seguridad y persistencia: migrar a DB y usar vector DB.

Licencia
- Añade un archivo `LICENSE` si quieres declarar la licencia del proyecto.

Contacto
- Repo: https://github.com/GersainAguilarPardo/ChatBot (rama feature/poc-chatbot)
- Si quieres que actualice colores exactos de Coztyc, pásame los códigos HEX oficiales y los aplico al CSS.

```
