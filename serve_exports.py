from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import os
import socket
import ssl

MINE_BY_EXT = {
    ".js": "text/javascript; charset=UTF-8",
    ".html": "text/html; charset=UTF-8",
    ".png": "image/png",
    ".webmanifest": "application/json; charset=UTF-8",
    ".ico": "image/ico",
    ".mp4": "video/mp4",
    ".svg": "image/svg+xml",
}


def current_ip():
    return socket.gethostname()


def _gen_cryptography():
    """Returns (cert, key) as ASCII PEM strings."""
    import datetime
    from cryptography import x509
    from cryptography.hazmat.backends import default_backend
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.asymmetric import rsa
    from cryptography.hazmat.primitives import serialization
    from cryptography.x509.oid import NameOID

    one_day = datetime.timedelta(1, 0, 0)
    private_key = rsa.generate_private_key(
        public_exponent=65537, key_size=2048, backend=default_backend()
    )
    public_key = private_key.public_key()

    builder = x509.CertificateBuilder()
    builder = builder.subject_name(
        x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, socket.gethostname())])
    )
    builder = builder.issuer_name(
        x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, socket.gethostname())])
    )
    builder = builder.not_valid_before(datetime.datetime.today() - one_day)
    builder = builder.not_valid_after(datetime.datetime.today() + (one_day * 365 * 5))
    builder = builder.serial_number(x509.random_serial_number())
    builder = builder.public_key(public_key)
    builder = builder.add_extension(
        x509.SubjectAlternativeName(
            [
                x509.DNSName(socket.gethostname()),
                x509.DNSName(f"*.{socket.gethostname()}"),
                x509.DNSName("localhost"),
                x509.DNSName("*.localhost"),
            ]
        ),
        critical=False,
    )
    builder = builder.add_extension(
        x509.BasicConstraints(ca=False, path_length=None), critical=True
    )

    certificate = builder.sign(
        private_key=private_key, algorithm=hashes.SHA256(), backend=default_backend()
    )

    return (
        certificate.public_bytes(serialization.Encoding.PEM),
        private_key.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8,
            serialization.NoEncryption(),
        ),
    )


def output_dir_path(*args):
    """Returns a path in the working directory.

    It contains the scraper output, converted images, and can be written to.
    """
    return os.path.join("exports", *args)


def _lazy_gen_cryptography():
    cert_path = output_dir_path("server.crt")
    key_path = output_dir_path("server.key")
    if os.path.isfile(cert_path) and os.path.isfile(key_path):
        print("Certificate files found. Reuse  existing certificates.")
        cert = open(cert_path, "rb").read()
        key = open(key_path, "rb").read()
    else:
        print("Certificate files not found. Generate certificates.")
        cert, key = _gen_cryptography()
        with open(cert_path, "wb") as out:
            out.write(cert)
        with open(key_path, "wb") as out:
            out.write(key)
    print(f" - Certificate {cert_path}")
    print(f" - Private key {key_path}")
    print(f"Install certificate as administrator with:")
    print(
        f'  powershell Import-Certificate -FilePath "{os.path.abspath(cert_path)}" -CertStoreLocation Cert:\LocalMachine\Root'
    )
    return cert_path, key_path


def run(https_port=443):

    class Handler(SimpleHTTPRequestHandler):
        def end_headers (self):
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
            self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
            SimpleHTTPRequestHandler.end_headers(self)

    cert_path, key_path = _lazy_gen_cryptography()
    server_address = ("", https_port)
    httpd = ThreadingHTTPServer(server_address, Handler)
    httpd.socket = ssl.wrap_socket(
        httpd.socket, keyfile=key_path, certfile=cert_path, server_side=True
    )

    print(f"Starting HTTPS server at https://localhost/exports")
    httpd.serve_forever()


if __name__ == "__main__":
    run()
