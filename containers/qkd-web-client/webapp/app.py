# webapp/app.py
from flask import Flask, render_template, request
import requests
import json
import ssl
import os
import subprocess

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/test_connection')
def test_connection():
    # Source the environment
    subprocess.run(". /opt/scripts/oqs_env.sh", shell=True)
    
    # Configure SSL context with QKD
    ctx = ssl.create_default_context()
    ctx.load_verify_locations("/opt/certs/dilithium/dilithium3_root_cert.pem")
    ctx.set_alpn_protocols(['h2'])
    
    algorithm = request.args.get('algorithm', 'qkd_mlkem512')
    
    try:
        # Make request to NGINX
        response = requests.get(
            'https://nginx-server:443/',
            verify='/opt/certs/dilithium/dilithium3_root_cert.pem',
            timeout=10
        )
        
        return {
            'success': True,
            'status_code': response.status_code,
            'headers': dict(response.headers),
            'content': response.text[:100]  # First 100 chars
        }
    except Exception as e:
        return {
            'success': False,
            'error': str(e)
        }

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)