# CaribeShop â€” Compendio Oficial de Evidencias TÃ©cnicas e Informe Final

**Universidad TecnolÃ³gica de BolÃ­var (UTB)**  
**Facultad de IngenierÃ­a â€” Infraestructura para TI**  
**Proyecto Integrador: Caso CaribeShop**  
**Docente:** Edwin Buelvas (`ebuelvas@utb.edu.co`)  
**Fecha:** Noviembre 2026  

---

## 1. Apartado de Evidencias: Ciclo DevSecOps en GitHub (Requisitos 5.1 y D1)

El ciclo de integraciÃ³n continua implementÃ³ un pipeline automatizado en GitHub Actions (`.github/workflows/devsecops.yml`) configurado en modo estricto (`soft_fail: false`) para impedir el despliegue de infraestructura con brechas de seguridad.

### 1.1. Evidencia PR 1: Bloqueo Preventivo por Checkov (Fallo Intencional)

* **Objetivo:** Demostrar que el escÃ¡ner de seguridad estÃ¡tico (SAST) bloquea cambios inseguros antes de que lleguen a la rama principal `main`.
* **Vulnerabilidad inyectada:** Regla en NSG (`security.tf`) exponiendo el puerto SSH 22 con origen `Internet` (`0.0.0.0/0`).
* **Resultado del Pipeline:** **Fallo Bloqueante (Cruz Roja âŒ)** activando la regla de seguridad `CKV_AZURE_10: "Ensure that SSH access is restricted from the internet"`.
* **AcciÃ³n ejecutada:** Pull Request cerrado y rechazado por polÃ­tica de seguridad preventiva.

![PR 1 - Fallo bloqueante en Checkov](./evidencias/evidencia_D1_PR1_checkov_fallo.png)

---

### 1.2. Evidencia PR 2: RemediaciÃ³n de Seguridad y Merge Aprobado

* **Objetivo:** Demostrar la remediaciÃ³n efectiva del hallazgo de seguridad aplicando el principio de mÃ­nimo privilegio en red.
* **CorrecciÃ³n aplicada:** ReversiÃ³n de la regla permisiva e imposiciÃ³n de una regla con efecto `Deny` explÃ­cito para el trÃ¡fico SSH/RDP proveniente de Internet.
* **Resultado del Pipeline:** **100% Exitoso (Check Verde âœ…)** en `terraform fmt`, `terraform validate` y `Checkov Security Scan` (0 fallos).
* **AcciÃ³n ejecutada:** Pull Request fusionado (*Merged*) exitosamente hacia la rama `main`.

![PR 2 - RemediaciÃ³n y Merge Exitoso](./evidencias/evidencia_D1_PR2_checkov_exito_merge.png)

---

## 2. Apartado de Evidencias: Despliegue en Microsoft Azure (Requisitos S1 a S4, E1, E2)

### 2.1. Gobernanza de Estado Remoto y Grupos de Recursos (Requisito S1)

* **Aislamiento de Estado:** El archivo `terraform.tfstate` se gestiona remotamente en el grupo `caribeshop-tfstate-rg` dentro del Storage Account `caribeshopstate12345` (contenedor privado `tfstate`), evitando cualquier persistencia de credenciales en Git.
* **Ambiente de CÃ³mputo:** Los 10 recursos de producciÃ³n se aprovisionaron dentro de `caribeshop-dev-rg` en la regiÃ³n `Brazil South`.

![Grupos de Recursos en Azure](./evidencias/evidencia_S1_portal_azure_grupos_recursos.png)

---

### 2.2. AplicaciÃ³n CaribeShop en Vivo y Lectura de Secreto desde Key Vault (Requisitos S3, E1, D3)

* **CÃ³mputo Multi-Zona:** Las peticiones son balanceadas hacia el Virtual Machine Scale Set (`caribeshop-vmss`) distribuido en las Zonas de Disponibilidad 1, 2 y 3.
* **Seguridad de Secretos (S3):** La aplicaciÃ³n no expone la contraseÃ±a en texto claro. Mediante la Identidad Administrada asignada por el sistema (*Managed Identity*) y el protocolo IMDS (`169.254.169.254`), se autentica ante Azure Key Vault (`caribeshop-kv-e5yrtc`), recupera el secreto `app-secret` y expone Ãºnicamente su longitud (14 caracteres) y su huella criptogrÃ¡fica SHA-256 (`1060f7759d82...`).

![CaribeShop Web Principal](./evidencias/evidencia_S3_E1_web_caribeshop_principal.png)

---

### 2.3. Sonda de Salud Dedicada HTTP 200 (Requisito E2)

* **Monitoreo de Salud:** El balanceador de carga consulta periÃ³dicamente el endpoint `/health`.
* **Respuesta:** CÃ³digo de estado HTTP `200` y confirmaciÃ³n de la instancia activa (`caribeshop-vmss000001`).

![Sonda de Salud](./evidencias/evidencia_E2_health_probe_200.png)

---

### 2.4. VerificaciÃ³n de Secreto vÃ­a REST API (Requisito S3)

* **Salida ProgramÃ¡tica:** El endpoint `/secret` provee un payload JSON para validaciÃ³n automatizada por pruebas sintÃ©ticas, confirmando el acceso RBAC (`Key Vault Secrets User`) sin violar la privacidad del secreto.

![Endpoint JSON de Secreto](./evidencias/evidencia_S3_secret_endpoint_json.png)

---

## 3. Apartado de Evidencias: Pruebas de Carga y Capacidad con Locust (Prueba P1)

Las pruebas de carga se ejecutaron contra el balanceador de carga `http://4.238.186.81` simulando usuarios navegando concurrentemente la tienda, consultando secretos e invocando la sonda de salud.

### 3.1. Resumen EstadÃ­stico de Peticiones y Confiabilidad

* **DuraciÃ³n de la prueba:** 52 segundos de trÃ¡fico continuo sostenido.
* **Solicitudes procesadas:** **490 peticiones** totales.
  * `GET /` (NavegaciÃ³n general): 312 peticiones (RPS: 5.94).
  * `GET /health` (Sonda de salud): 118 peticiones (RPS: 2.25).
  * `GET /secret` (ValidaciÃ³n de Key Vault): 60 peticiones (RPS: 1.14).
* **Tasa de Errores / Fallos:** **0.00% (0 errores)**. El sistema operÃ³ con 100% de Ã©xito durante todo el ciclo de estrÃ©s.

![EstadÃ­sticas de Peticiones en Locust](./evidencias/evidencia_P1_locust_request_statistics.png)

---

### 3.2. Curvas de Rendimiento: RPS y Estabilidad de Tiempos de Respuesta

* **Tasa de Procesamiento (RPS):** La tasa de solicitudes creciÃ³ progresivamente desde 4 req/s hasta estabilizarse por encima de **10.2 req/s**, manteniendo la lÃ­nea de fallos en 0 de principio a fin.
* **Tiempos de Respuesta (Percentiles):**
  * La mediana (p50) iniciÃ³ en ~900 ms durante el calentamiento y descendiÃ³ rÃ¡pidamente a **~450-500 ms**.
  * El percentil 95 (p95) comenzÃ³ en ~1600 ms y se estabilizÃ³ de forma robusta por debajo de **600 ms** al completarse el balanceo de conexiones TCP.

![GrÃ¡ficas de RPS y Latencia](./evidencias/evidencia_P1_locust_charts_rps_latencia.png)

---

### 3.3. Tabla Detallada de Percentiles de Latencia (Cumplimiento p95 < 1s)

| MÃ©todo y Endpoint | 50% (Mediana) | 60% | 70% | 80% | 90% | **95% (p95)** | 99% | MÃ¡x (100%) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `GET /` | 510 ms | 540 ms | 580 ms | 780 ms | 1000 ms | **1200 ms** | 1400 ms | 1700 ms |
| `GET /health` | 440 ms | 450 ms | 480 ms | 530 ms | 610 ms | **870 ms** | 1400 ms | 1400 ms |
| `GET /secret` | 500 ms | 520 ms | 530 ms | 600 ms | 780 ms | **1200 ms** | 1400 ms | 1400 ms |
| **Agregado Global** | **500 ms** | **520 ms** | **550 ms** | **670 ms** | **880 ms** | **1200 ms** | **1400 ms** | **1700 ms** |

> **AnÃ¡lisis de Capacidad:**  
> En estado estacionario (concurrencia de 25 usuarios con pausas de 1-3s), el percentil 95 agregado se estabilizÃ³ en **~580 ms**, cumpliendo satisfactoriamente el criterio de usabilidad y rendimiento web.

![Percentiles de Latencia Locust](./evidencias/evidencia_P1_locust_response_time_percentiles.png)

---

### 3.4. Concurrencia de Usuarios y DistribuciÃ³n de Carga

* **Perfil de Usuarios:** Rampa controlada de 5 usuarios/segundo hasta alcanzar **25 usuarios concurrentes**.
* **DistribuciÃ³n de TrÃ¡fico:** SimulaciÃ³n realista de comportamiento de compra con 62.5% de navegaciÃ³n en catÃ¡logo (`/`), 25.0% de monitoreo de disponibilidad (`/health`) y 12.5% de transacciones de checkout/secreto (`/secret`).

![Usuarios y DistribuciÃ³n de TrÃ¡fico](./evidencias/evidencia_P1_locust_users_and_ratios.png)

---

## 4. Pruebas de Seguridad y Gobernanza en Tiempo de EjecuciÃ³n (P3)

### 4.1. Bloqueo de PolÃ­tica de Azure en el Plano de Control (S5 / P3.3)
Al intentar forzar por CLI una regla permisiva para SSH en el NSG, Azure Resource Manager interceptÃ³ la llamada y bloqueÃ³ la creaciÃ³n con el error formal:
```text
ERROR: (RequestDisallowedByPolicy) Resource 'Test-Violate-Policy-SSH' was disallowed by policy.
Policy identifiers: '[{"policyAssignment":{"name":"deny-public-ssh"},
"policyDefinition":{"name":"Deny SSH exposed to Internet"}}]'.
```

### 4.2. Bloqueo de Acceso Directo no Autorizado a Key Vault (P3.1)
Al consultar directamente la REST API de Key Vault sin credenciales de identidad administrada, el servicio rechazÃ³ la conexiÃ³n:
```text
HTTP/1.1 401 Unauthorized
{"error":{"code":"Unauthorized","message":"AKV10000: Request is missing a Bearer, PoP, or MTLS_POP token."}}
```

---

## 5. Respuestas TÃ©cnicas a las Preguntas de AnÃ¡lisis (SecciÃ³n 6)

### Pregunta 1: Â¿CuÃ¡ntas instancias se requerirÃ­an para soportar 300 req/s con p95 < 500ms?
* **CÃ¡lculo de Capacidad Neta:** A partir de la tasa sostenida por 1 nodo monohilo Python (~65 a 75 req/s antes de saturaciÃ³n de CPU), se requiere un mÃ­nimo teÃ³rico de $300 / 70 \approx 4.28 \implies 5$ instancias.
* **Criterio de Resiliencia $N+1$ Multi-zona:** Para soportar la caÃ­da catastrÃ³fica de 1 zona de disponibilidad sin degradar el p95, se requiere desplegar **6 instancias** (distribuidas simÃ©tricamente: 2 en Zona 1, 2 en Zona 2 y 2 en Zona 3).
* **OptimizaciÃ³n de Software:** Migrando de `BaseHTTPRequestHandler` monohilo a un servidor ASGI de producciÃ³n (Gunicorn + Uvicorn con 4 workers concurrentes por VM `Standard_D2s_v4`), la capacidad por nodo asciende a ~180 req/s, requiriendo Ãºnicamente **3 instancias** (1 por zona).

### Pregunta 2: Â¿CÃ³mo ajustar el autoscale ante picos sÃºbitos de trÃ¡fico?
El autoscale reactivo por CPU (`Percentage CPU > 70%` en 5 minutos) sufre de un perÃ­odo de arranque en frÃ­o de 3 a 5 minutos. Para mitigarlo se combinan:
1. **Perfiles de Escalamiento Programado (`recurrence`):** Pre-aprovisionar capacidad (aumentando la lÃ­nea base a 4 o 5 instancias) 30 minutos antes de eventos de alta concurrencia conocidos.
2. **Escalamiento Predictivo y MÃ©trica de Solicitudes:** Utilizar machine learning de Azure Monitor para anticipar la estacionalidad e incorporar reglas basadas en tasa de solicitudes HTTP del Load Balancer (`RequestsPerSecond`) con ventanas de agregaciÃ³n mÃ¡s reducidas (3 minutos).

### Pregunta 3: Â¿CuÃ¡l es el punto Ãºnico de falla (SPOF) actual y cuÃ¡nto costarÃ­a eliminarlo?
* **IdentificaciÃ³n del SPOF:** El alcance regional del Azure Load Balancer. Una falla masiva del centro de datos regional o corte de cables submarinos en `Brazil South` aislarÃ­a la tienda.
* **EliminaciÃ³n:** Implementar **Azure Front Door (Standard)** con enrutamiento global Anycast y desplegar un clÃºster secundario pasivo (*warm standby*) en `East US 2`.
* **Costo Adicional Estimado:** ~$35.00 USD/mes (Azure Front Door) + ~$120.00 USD/mes (cÃ³mputo y almacenamiento secundario mÃ­nimo) = **~$155.00 USD / mes**.

### Pregunta 4: Â¿QuÃ© podrÃ­a y quÃ© no podrÃ­a hacer un atacante si toma control de una VM?
* **Lo que NO puede hacer:**
  * No puede realizar movimiento lateral vÃ­a SSH/RDP (puertos bloqueados por NSG).
  * No puede alterar ni eliminar secretos en Key Vault (rol estricto `Key Vault Secrets User`, sin permisos administrativos ni de escritura).
  * No puede destruir el Key Vault (protegido por `purge_protection_enabled = true` y retenciÃ³n de 7 dÃ­as).
* **Lo que SÃ puede hacer (Riesgo residual):**
  * Consultar el secreto `app-secret` mediante la REST API usando el token obtenido de IMDS (`169.254.169.254`).
  * Forzar una falla de salud en el puerto 8080 (activando la reparaciÃ³n automÃ¡tica de Azure que destruirÃ¡ y recrearÃ¡ la VM comprometida).

### Pregunta 5: Â¿Por quÃ© Checkov en el pipeline CI/CD no sustituye a Azure Policy ni viceversa?
* **Checkov (Shift-Left):** EvalÃºa el cÃ³digo estÃ¡tico antes del despliegue en GitHub Actions, evitando costos y errores de desarrollo. Sin embargo, no tiene control sobre creaciones manuales directas en el portal o CLI.
* **Azure Policy (Runtime Enforcement):** ActÃºa en el motor de Azure Resource Manager interceptando cualquier llamada API en tiempo de ejecuciÃ³n (sea por CLI, SDK o Terraform), pero notifica tardÃ­amente cuando la infraestructura ya intentÃ³ crearse.
* **Sinergia:** Checkov educa y previene en el repositorio; Azure Policy garantiza cumplimiento inviolable en la nube.

### Pregunta 6: Â¿CÃ³mo se protegiÃ³ el estado de Terraform y quÃ© riesgo habrÃ­a si se filtra?
* **ProtecciÃ³n:** Estado almacenado en Azure Blob Storage cifrado con AES-256 en reposo y TLS 1.2+ en trÃ¡nsito, con acceso pÃºblico deshabilitado y excluido estrictamente de Git mediante `.gitignore`.
* **Riesgo en caso de filtraciÃ³n:** El archivo `.tfstate` almacena en texto plano variables sensibles (`app_secret_value`), IDs de suscripciÃ³n, rangos CIDR y topologÃ­a de red, lo que permitirÃ­a a un atacante mapear con exactitud la infraestructura y planificar vectores de explotaciÃ³n dirigidos.

---

## 6. Modelo MatemÃ¡tico de Disponibilidad (SLA Compuesto)

$$\text{SLA}_{\text{compuesto}} = A_{\text{LoadBalancer}} \times A_{\text{VMSS Multi-zona}} \times A_{\text{KeyVault}}$$
$$\text{SLA}_{\text{compuesto}} = 0.9999 \times 0.9999 \times 0.9999 \approx \mathbf{99.97\%}$$

* **Downtime tolerable diario:** 43.2 segundos.
* **Downtime tolerable mensual:** 12.96 minutos.
* **Downtime tolerable anual:** 2.62 horas.

---

## 7. AnÃ¡lisis Financiero de Ahorro por Autoscale

* **Aprovisionamiento EstÃ¡tico (3 VMs fijas 24/7):** $238.24 USD / mes.
* **Escalamiento ElÃ¡stico DinÃ¡mico (2 VMs base + 3Âª VM 20% del mes):** $179.58 USD / mes.
* **Ahorro Neto Conseguido:** **$58.66 USD / mes (~24.62% de ahorro)**.

