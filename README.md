# Lightweight Chromium for AWS Lambda

A minimal, optimized Chromium binary and dependencies specifically designed for AWS Lambda environments. Perfect for PDF generation, web scraping, and headless browser automation in serverless applications.

## 🚀 Features

- **Lightweight**: ~168MB optimized Chromium binary (vs 200MB+ full Chrome)
- **Lambda Ready**: Pre-configured for AWS Lambda runtime environment
- **Complete**: Includes all necessary shared libraries
- **Tested**: Battle-tested in production Lambda environments
- **Python Compatible**: Works seamlessly with Pyppeteer and Playwright

## 📦 Contents

```
bin/
├── chromium                    # Optimized Chromium binary (168MB)
├── lib/                       # Shared libraries
│   ├── libexpat.so.1         # XML parsing library
│   ├── libnss3.so            # Network Security Services
│   ├── libnssutil3.so        # NSS utilities
│   ├── libsoftokn3.so        # NSS cryptographic library
│   ├── libsqlite3.so.0       # SQLite database
│   └── libuuid.so.1          # UUID generation
├── pyppeteer-install         # Pyppeteer install script
└── tqdm                      # Progress bar utility
```

## 🛠 Installation

### Method 1: Direct Download

```bash
# Download the binary (raw URL — the /blob/ URL would download HTML, not the zip)
wget https://raw.githubusercontent.com/aniketkarne/chromium-binary-lightweight/main/chromium-lambda.zip

# Or with curl
curl -L -o chromium-lambda.zip https://raw.githubusercontent.com/aniketkarne/chromium-binary-lightweight/main/chromium-lambda.zip

# Extract
unzip chromium-lambda.zip

# Make executable
chmod +x bin/chromium
```

### Method 2: Git Clone

```bash
git clone https://github.com/aniketkarne/chromium-binary-lightweight.git
cd chromium-binary-lightweight
unzip chromium-lambda.zip
chmod +x bin/chromium
```

## 🐍 Python Usage

### With Pyppeteer

```python
import os
from pyppeteer import launch

# Set Chromium path
chromium_path = "/path/to/chromium-lambda/bin/chromium"

# Configure for Lambda
if os.environ.get('AWS_LAMBDA_FUNCTION_NAME'):
    # Lambda environment
    browser = await launch(
        executablePath=chromium_path,
        args=[
            '--no-sandbox',
            '--disable-dev-shm-usage',
            '--disable-gpu',
            '--remote-debugging-port=9222',
            '--single-process',
            '--no-zygote'
        ]
    )
else:
    # Local development
    browser = await launch(executablePath=chromium_path)

# Generate PDF
page = await browser.newPage()
await page.goto('https://example.com')
pdf = await page.pdf({'format': 'A4'})
await browser.close()
```

### With Playwright

```python
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(
            executable_path="/path/to/chromium-lambda/bin/chromium",
            args=['--no-sandbox', '--disable-dev-shm-usage']
        )
        page = await browser.new_page()
        await page.goto('https://example.com')
        await page.pdf(path='example.pdf')
        await browser.close()
```

## 🚀 AWS Lambda Integration

### Lambda Layer Setup

```bash
# Create layer structure
mkdir -p chromium-layer/bin
cp -r bin/* chromium-layer/bin/

# Set library path
export LD_LIBRARY_PATH="/opt/bin/lib:$LD_LIBRARY_PATH"

# Create layer zip
cd chromium-layer
zip -r ../chromium-layer.zip .
```

### Environment Variables

```python
import os

# Lambda configuration
if os.environ.get('AWS_LAMBDA_FUNCTION_NAME'):
    os.environ['PYPPETEER_HOME'] = '/tmp'
    os.environ['HOME'] = '/tmp'
    
    # Add library path
    current_ld_path = os.environ.get('LD_LIBRARY_PATH', '')
    os.environ['LD_LIBRARY_PATH'] = f"/opt/bin/lib:{current_ld_path}"
```

### Docker Build Example

```dockerfile
FROM public.ecr.aws/lambda/python:3.11

# Copy Chromium binary and libraries
COPY bin/ /opt/bin/
RUN chmod +x /opt/bin/chromium

# Set library path
ENV LD_LIBRARY_PATH="/opt/bin/lib:${LD_LIBRARY_PATH}"

# Install Python dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy application code
COPY app/ ${LAMBDA_TASK_ROOT}/

CMD ["lambda_handler.handler"]
```

## ⚙️ Configuration

### Lambda Function Settings

```yaml
Runtime: python3.11
MemorySize: 512MB # Minimum recommended
Timeout: 30s # Adjust based on workload
Environment:
  Variables:
    PYPPETEER_EXECUTABLE_PATH: "/opt/bin/chromium"
    LD_LIBRARY_PATH: "/opt/bin/lib"
```

### Chromium Launch Arguments

```python
# Production Lambda args
LAMBDA_ARGS = [
    '--no-sandbox',
    '--disable-dev-shm-usage',
    '--disable-gpu',
    '--remote-debugging-port=9222',
    '--single-process',
    '--no-zygote',
    '--disable-web-security',
    '--disable-features=VizDisplayCompositor'
]

# Development args
DEV_ARGS = [
    '--no-sandbox',
    '--disable-web-security'
]
```

## 📊 Performance

| Metric | Value |
|--------|-------|
| Binary Size | ~168MB |
| Cold Start | +2-3s |
| Memory Usage | ~100-150MB |
| PDF Generation | ~1-3s |

## 🔧 Troubleshooting

### Common Issues

**1. Permission Denied**
```bash
chmod +x bin/chromium
```

**2. Missing Libraries**
```bash
# Verify libraries are present
ls -la bin/lib/
export LD_LIBRARY_PATH="/path/to/bin/lib:$LD_LIBRARY_PATH"
```

**3. Lambda Timeout**
```python
# Increase timeout and memory
# Use single-process mode
args=['--single-process', '--no-zygote']
```

**4. Font Issues**
```python
# Install basic fonts in Lambda
args=['--disable-dev-shm-usage', '--disable-gpu']
```

## 🧪 Testing

```python
import asyncio
from pyppeteer import launch

async def test_chromium():
    browser = await launch(
        executablePath='./bin/chromium',
        args=['--no-sandbox']
    )
    page = await browser.newPage()
    await page.goto('data:text/html,<h1>Test</h1>')
    content = await page.content()
    print("✅ Chromium working:", "Test" in content)
    await browser.close()

# Run test
asyncio.run(test_chromium())
```

## 📝 Requirements

```txt
# For Pyppeteer
pyppeteer>=1.0.0

# For Playwright  
playwright>=1.0.0

# AWS Lambda
boto3>=1.26.0
```

## 🏗 Build from Source

```bash
# If you want to build your own optimized binary
git clone https://chromium.googlesource.com/chromium/src
cd src

# Configure for Lambda
gn gen out/Lambda --args='
  is_debug=false
  is_component_build=false
  use_goma=false
  enable_nacl=false
  remove_webcore_debug_symbols=true
'

# Build
ninja -C out/Lambda chrome
```

## 📄 License

This repository is released under the [BSD 3-Clause License](./LICENSE). The
`chromium` binary inside `chromium-lambda.zip` is derived from upstream
Chromium, which is also BSD 3-Clause licensed by The Chromium Authors — see
https://chromium.googlesource.com/chromium/src/+/main/LICENSE for the
upstream license text that applies to the binary itself.

## 🤝 Contributing

1. Fork the repository
2. Test your changes in Lambda environment
3. Submit a pull request

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/aniketkarne/chromium-binary-lightweight/issues)
- **Discussions**: [GitHub Discussions](https://github.com/aniketkarne/chromium-binary-lightweight/discussions)

## 🔖 Version History

| Version | Date | Notes |
|---------|------|-------|
| v1.0.0  | 2025-06-27 | Initial release. Chromium binary built 2025-06-27 (Chromium 114 series). |
| v1.1.0  | 2025-07-14 | Trimmed binary size by ~20MB. |
| v1.2.0  | 2025-07-15 | Documented Playwright usage path. |

> **Heads up — Chromium build date:** the `chromium` binary inside
> `chromium-lambda.zip` was last built on **2025-06-27**. That's fine for most
> PDF / scraping workloads, but if you need a recent Chromium (security
> patches, new headless features, modern JS support) you'll want to rebuild
> from source — see [Build from Source](#-build-from-source) below. A
> refreshed prebuilt binary is tracked as a follow-up.

---

**⭐ Star this repo if it helped you!**

Built with ❤️ for the serverless community.
