"""
================================================================================
CaribeShop - Script de Pruebas de Carga con Locust
Pruebas obligatorias P1 (Carga y Escalamiento) y P2 (Pruebas de Falla)
Taller Integrador - Infraestructura para TI - UTB
================================================================================

Instalación previa de Locust:
    pip install locust

Instrucciones de Ejecución:

1. Medir capacidad de 1 instancia (P1.1):
   - Ajustar temporalmente en autoscale: min = max = desired = 1 (vía Terraform o Portal).
   - Ejecutar con interfaz web:
       locust -f locustfile.py --host=http://<IP_PUBLICA_LB>
   - O ejecutar en modo headless:
       locust -f locustfile.py --host=http://<IP_PUBLICA_LB> --headless -u 50 -r 5 --run-time 10m

2. Prueba escalonada de 25 minutos con generación de evidencias CSV y HTML (P1.2):
   - Restaurar el autoscale normal (min = 2, max = 3).
   - Ejecutar guardando reporte en la carpeta 'evidencias/':
       locust -f locustfile.py --host=http://<IP_PUBLICA_LB> --headless -u 150 -r 5 --run-time 25m --csv=evidencias/locust_escalonada --html=evidencias/locust_reporte.html

3. Pruebas de falla (P2.1 y P2.2):
   - Mientras Locust genera carga moderada (-u 40):
     * Falla lógica: llamar a /simulate-fail en una instancia o forzar 503 en /health.
     * Falla abrupta: eliminar/reiniciar una VM del scale set desde el portal o Azure CLI.
================================================================================
"""

from locust import HttpUser, task, between, tag

class CaribeShopCustomer(HttpUser):
    # Tiempo de espera simulado entre peticiones de cada usuario (entre 1 y 3 segundos)
    wait_time = between(1.0, 3.0)

    @tag("tienda")
    @task(5)
    def browse_store(self):
        """Simula a un cliente navegando la página principal de CaribeShop"""
        with self.client.get("/", catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"HTTP {response.status_code}: {response.text}")

    @tag("salud")
    @task(2)
    def check_health(self):
        """Simula verificación de la sonda de salud del balanceador"""
        with self.client.get("/health", catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            elif response.status_code == 503:
                # Durante la prueba P2.1, el 503 es esperado temporalmente
                response.failure("Instancia en fallo lógico (503 Service Unavailable)")
            else:
                response.failure(f"Error inesperado en sonda: {response.status_code}")

    @tag("seguridad")
    @task(1)
    def query_secret_endpoint(self):
        """Simula una consulta al endpoint protegido que lee el secreto desde Key Vault"""
        with self.client.get("/secret", catch_response=True) as response:
            if response.status_code == 200:
                try:
                    data = response.json()
                    if data.get("status") == "success":
                        response.success()
                    else:
                        response.failure(f"Error en lectura de secreto: {data.get('message')}")
                except Exception as e:
                    response.failure(f"Error decodificando respuesta JSON: {str(e)}")
            else:
                response.failure(f"Error HTTP {response.status_code}")
