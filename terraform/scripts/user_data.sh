#!/bin/bash
set -e

mkdir -p /opt/caribeshop

# Crear script de la aplicación CaribeShop
# Cumple Requisito S3 (lectura de secreto vía IMDS + Key Vault sin dependencias externas)
# y Requisito P2.1 (inyección de fallo lógico respondiendo 503 en /health)
cat > /opt/caribeshop/app.py << 'PY'
import json
import hashlib
import os
import socket
import urllib.request
import urllib.error
from http.server import BaseHTTPRequestHandler, HTTPServer

VAULT_NAME = "${vault_name}"
SECRET_NAME = "app-secret"
FAIL_FLAG_FILE = "/tmp/caribeshop_fail"

def get_secret_metadata():
    """Obtiene el secreto desde Key Vault usando la Identidad Administrada (IMDS)"""
    try:
        # 1. Obtener token OAuth2 para Azure Key Vault desde IMDS (Requisito S3 / Sección 8.1)
        imds_url = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net"
        req = urllib.request.Request(imds_url, headers={"Metadata": "true"})
        with urllib.request.urlopen(req, timeout=5) as response:
            token_data = json.loads(response.read().decode())
            access_token = token_data["access_token"]

        # 2. Consultar el secreto en Key Vault
        kv_url = f"https://{VAULT_NAME}.vault.azure.net/secrets/{SECRET_NAME}?api-version=7.4"
        kv_req = urllib.request.Request(kv_url, headers={"Authorization": f"Bearer {access_token}"})
        with urllib.request.urlopen(kv_req, timeout=5) as kv_response:
            kv_data = json.loads(kv_response.read().decode())
            secret_value = kv_data.get("value", "")
            
            # Buenas prácticas de seguridad (Requisito S3): NO mostrar el secreto en texto claro
            secret_hash = hashlib.sha256(secret_value.encode()).hexdigest()[:12]
            return {
                "status": "success",
                "length": len(secret_value),
                "sha256_prefix": secret_hash,
                "vault": VAULT_NAME,
                "secret_name": SECRET_NAME
            }
    except Exception as e:
        return {
            "status": "error",
            "message": str(e),
            "vault": VAULT_NAME,
            "secret_name": SECRET_NAME
        }

class CaribeShopHandler(BaseHTTPRequestHandler):
    def _send_response(self, code, content_type, body):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("X-Hostname", socket.gethostname())
        self.end_headers()
        if isinstance(body, str):
            body = body.encode("utf-8")
        self.wfile.write(body)

    def do_GET(self):
        hostname = socket.gethostname()

        # Requisito E2 y P2.1: Sonda de salud y prueba de fallo
        if self.path == "/health":
            if os.path.exists(FAIL_FLAG_FILE):
                self._send_response(503, "application/json", json.dumps({
                    "status": "unhealthy",
                    "code": 503,
                    "instance": hostname,
                    "reason": "Simulated failure active"
                }))
            else:
                self._send_response(200, "application/json", json.dumps({
                    "status": "healthy",
                    "code": 200,
                    "instance": hostname
                }))
            return

        # Requisito P2.1: Endpoints de control de fallo para pruebas
        if self.path == "/simulate-fail":
            with open(FAIL_FLAG_FILE, "w") as f:
                f.write("failing")
            self._send_response(200, "text/plain", f"Instance {hostname} marked as FAILING (health now returns 503)\n")
            return

        if self.path == "/simulate-recover":
            if os.path.exists(FAIL_FLAG_FILE):
                os.remove(FAIL_FLAG_FILE)
            self._send_response(200, "text/plain", f"Instance {hostname} RECOVERED (health now returns 200)\n")
            return

        # Requisito S3: Demostración de lectura de secreto vía Key Vault
        if self.path == "/secret":
            meta = get_secret_metadata()
            meta["instance"] = hostname
            self._send_response(200, "application/json", json.dumps(meta, indent=2))
            return

        # Página Principal (HTML)
        meta = get_secret_metadata()
        html = f"""<!DOCTYPE html>
<html>
<head>
    <title>CaribeShop - Plataforma de Alta Disponibilidad</title>
    <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 40px; background: #f8f9fa; color: #212529; }}
        .card {{ background: white; border-radius: 8px; padding: 24px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); max-width: 700px; margin: 0 auto; }}
        h1 {{ color: #0066cc; margin-top: 0; }}
        .badge {{ display: inline-block; padding: 4px 8px; border-radius: 4px; font-weight: bold; background: #28a745; color: white; }}
        .badge-fail {{ background: #dc3545; }}
        table {{ width: 100%; border-collapse: collapse; margin-top: 20px; }}
        td, th {{ padding: 10px; border-bottom: 1px solid #dee2e6; text-align: left; }}
        code {{ background: #e9ecef; padding: 2px 6px; border-radius: 4px; }}
    </style>
</head>
<body>
    <div class="card">
        <h1>CaribeShop &bull; Tienda Oficial</h1>
        <p>Plataforma de alta disponibilidad, autoescalable y segura desplegada con Terraform en Azure.</p>
        
        <table>
            <tr><th>Instancia VMSS</th><td><code>{hostname}</code></td></tr>
            <tr><th>Estado de Salud</th><td><span class="badge">Healthy (200)</span></td></tr>
            <tr><th>Azure Key Vault</th><td><code>{meta.get('vault')}</code></td></tr>
            <tr><th>Secreto Le&iacute;do</th><td><code>{meta.get('secret_name')}</code></td></tr>
            <tr><th>Longitud del Secreto (S3)</th><td><code>{meta.get('length')} caracteres</code></td></tr>
            <tr><th>Huella SHA-256 (S3)</th><td><code>{meta.get('sha256_prefix')}...</code></td></tr>
            <tr><th>Estado de Lectura RBAC</th><td><code>{meta.get('status')}</code></td></tr>
        </table>

        <h3>Endpoints de Prueba:</h3>
        <ul>
            <li><code>/health</code> - Sonda de salud (Requisito E2)</li>
            <li><code>/secret</code> - Verificaci&oacute;n de secreto en JSON (Requisito S3)</li>
            <li><code>/simulate-fail</code> - Inyectar fallo 503 para prueba P2.1</li>
            <li><code>/simulate-recover</code> - Recuperar salud a 200</li>
        </ul>
    </div>
</body>
</html>"""
        self._send_response(200, "text/html", html)

HTTPServer(("0.0.0.0", 8080), CaribeShopHandler).serve_forever()
PY

# Configurar servicio systemd
cat > /etc/systemd/system/caribeshop.service << 'SERVICE'
[Unit]
Description=CaribeShop Web Application Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/caribeshop/app.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable caribeshop
systemctl restart caribeshop
