#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

set -e

createStructure() {
    echo -e "${YELLOW}🏗️ Creating Django Project Structure${NC}"
    
    # Create virtual environment and install Django
    python3 -m venv .venv
    source .venv/bin/activate
    pip install --upgrade pip
    pip install django python-dotenv pandas openpyxl
    
    # Create Django project
    django-admin startproject config .
    python manage.py startapp dashboard
    python manage.py startapp files
    python manage.py startapp data
    
    # Create additional directories
    mkdir -p {media/uploads,media/downloads,static}
    
    # Create other files
    touch .env .gitignore README.md
}

generateGitignore() {
    cat > .gitignore << EOL
*.pyc
__pycache__/
.venv/
.env
db.sqlite3
.vscode/
media/
EOL
}

generateEnv() {
    cat > .env << EOL
SECRET_KEY=$(python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
DEBUG=False
ALLOWED_HOSTS=localhost,127.0.0.1
MAX_UPLOAD_SIZE=16777216
EOL
}

updateSettings() {
    cat > config/settings.py << EOL
import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent
SECRET_KEY = os.getenv('SECRET_KEY')
DEBUG = os.getenv('DEBUG', 'False') == 'False'
ALLOWED_HOSTS = os.getenv('ALLOWED_HOSTS', '').split(',')

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'dashboard',
    'files',
    'data',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'config.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'config.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
STATICFILES_DIRS = [BASE_DIR / 'static']

MEDIA_URL = 'media/'
MEDIA_ROOT = BASE_DIR / 'media'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
EOL
}

createUrls() {
    # Main URLs
    cat > config/urls.py << EOL
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.shortcuts import redirect

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', lambda request: redirect('dashboard/')),
    path('dashboard/', include('dashboard.urls')),
    path('files/', include('files.urls')),
    path('data/', include('data.urls')),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
EOL

    # Dashboard URLs
    cat > dashboard/urls.py << EOL
from django.urls import path
from . import views

app_name = 'dashboard'

urlpatterns = [
    path('', views.dashboard, name='dashboard'),
    path('files/', views.files, name='files'),
    path('chat/', views.chat, name='chat'),
]
EOL

    # Files URLs
    cat > files/urls.py << EOL
from django.urls import path
from . import views

app_name = 'files'

urlpatterns = [
    path('', views.read_excel, name='read_excel'),
]
EOL

    # Data URLs
    cat > data/urls.py << EOL
from django.urls import path
from . import views

app_name = 'data'

urlpatterns = [
    path('', views.excel_data, name='excel_data'),
]
EOL
}

createViews() {
    # Dashboard Views
    cat > dashboard/views.py << EOL
from django.shortcuts import render

def dashboard(request):
    return render(request, 'dashboard/dashboard.html')

def files(request):
    return render(request, 'dashboard/files.html')

def chat(request):
    return render(request, 'dashboard/chat.html')
EOL

    # Files Views
    cat > files/views.py << EOL
from django.shortcuts import render
import pandas as pd

def read_excel(request):
    if request.method == 'POST':
        if 'file' not in request.FILES:
            return render(request, 'files/files.html', {'error': 'Upload a file'})
        
        file = request.FILES['file']
        
        if not file.name.lower().endswith(('.xls', '.xlsx', '.xlsm', '.xlsb')):
            return render(request, 'files/files.html', {'error': 'Invalid file type'})
        
        try:
            df = pd.read_excel(file)
            stats = {
                'filename': file.name,
                'total_rows': len(df),
                'total_value': df.iloc[:, -1].sum(),
                'average_value': df.iloc[:, -1].mean(),
                'null_values': df.isnull().sum().sum()
            }
            
            return render(request, 'data/excel_data.html', {
                'stats': stats,
                'data': df.to_dict('records'),
                'columns': df.columns.tolist()
            })
            
        except Exception as e:
            return render(request, 'files/files.html', {'error': str(e)})
    
    return render(request, 'files/files.html')
EOL

    # Data Views
    cat > data/views.py << EOL
from django.shortcuts import render

def excel_data(request):
    return render(request, 'data/excel_data.html')
EOL
}

createAppConfigs() {
    for app in dashboard files data; do
        app_config=$(echo "$app" | sed 's/[^a-zA-Z0-9_]/_/g' | sed 's/^_//' | sed 's/_$//')Config  # Create a valid class name
        cat > "$app/apps.py" << EOL
from django.apps import AppConfig

class ${app_config}(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = '$app'
EOL
    done
}

createTemplates() {
    echo -e "${YELLOW}📄 Creating Templates${NC}"
    mkdir -p dashboard/templates/dashboard
    mkdir -p files/templates/files
    mkdir -p data/templates/data
    touch dashboard/templates/dashboard/dashboard.html
    touch files/templates/files/files.html
    touch dashboard/templates/dashboard/chat.html
    touch data/templates/data/excel_data.html

    cat > dashboard/templates/dashboard/dashboard.html << EOL
{% load static %}

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css">
    <link rel="stylesheet" href="{% static 'dashStyle.css' %}">
    <link rel="shortcut icon" href="{% static 'img/favicon.png' %}" type="image/x-icon">
    <link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet">
</head>
<body>
    {% if messages %}
        {% for message in messages %}
            <div class="error-message">{{ message }}</div>
        {% endfor %}
    {% endif %}

    <div class="topnav-container">
        <div>
            <a href="{% url 'dashboard:dashboard' %}" class="logoIN">
                <div class="nomPag">Dashboard</div>
            </a>
        </div>
        <div class="topnav">
            <a href="{% url 'dashboard:dashboard' %}"><i class="fa fa-bar-chart" style="color: #0b00a2;"></i></a>
        </div>
    </div>

    <div class="column">
        <div class="card">
            <a href="{% url 'dashboard:files' %}" style="color: green;"><i class="fa fa-file-o"><span class="titles">Analizar Archivo</span></i><i class="fa fa-upload" style="color: #0b00a2;"></i></a>
        </div>
    </div>

    <div class="column">
        <div class="card">
            <a href="{% url 'dashboard:chat' %}"><i class="fa fa-comment-o"><span class="titles">Preguntar Arpa</span></i><i class="fa fa-keyboard-o"></i></a>
        </div>
    </div>
</body>
</html>


EOL

    
    cat > dashboard/templates/dashboard/files.html << EOL
{% load static %}
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Excel</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css">
    <link rel="stylesheet" href="{% static 'dashStyle.css' %}">
    <link rel="shortcut icon" href="{% static 'img/favicon.png' %}" type="image/x-icon">
    <link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet">
</head>
<body>
    <div class="topnav-container">
        <div>
            <a href="{% url 'dashboard:dashboard' %}" class="logoIN">
                <div class="nomPag">Analizar</div>
            </a>
        </div>
        <div class="topnav">
            <a href="{% url 'dashboard:files' %}"><i class="fa fa-upload"></i></a>
            <a href="{% url 'dashboard:dashboard' %}"><i class="fa fa-bar-chart"></i></a>
        </div>
    </div>

    {% if error %}
    <div class="error">
        {{ error }}
    </div>
    {% endif %}

    <div class="dashboard">
        <form class="stats-grid" method="POST" enctype="multipart/form-data" action="{% url 'files:read_excel' %}">
            {% csrf_token %}
            <div class="stat-card">
                <div class="stat-value"><input type="file" name="file" accept=".xls,.xlsx"></div>
            </div>
            <div class="stat-card">
                <div class="stat-value"><input type="submit" value="Analizar"></div>
            </div>
        </form>
    </div>
</body>
</html>

EOL

    cat > dashboard/templates/dashboard/chat.html << EOL
{% load static %}
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Chat</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css">
    <link rel="stylesheet" href="{% static 'dashStyle.css' %}">
    <link rel="shortcut icon" href="{% static 'img/favicon.png' %}" type="image/x-icon">
    <link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/socket.io/4.8.1/socket.io.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.7.1/jquery.min.js"></script>
</head>
<body>
    {% if messages %}
        {% for message in messages %}
            <div class="error-message">{{ message }}</div>
        {% endfor %}
    {% endif %}

    <div class="topnav-container">
        <div>
            <a href="{% url 'dashboard:dashboard' %}" class="logoIN">
                <div class="nomPag">Arpa</div>
            </a>
        </div>
        <div class="topnav">
            <a href="{% url 'dashboard:chat' %}"><i class="fa fa-comment-o"></i></a>
            <a href="{% url 'dashboard:dashboard' %}"><i class="fa fa-bar-chart"></i></a>
        </div>
    </div>

    <div class="chat-container" id="chat-container">
        {% for message in chat_messages %}
            <div class="message {{ message.role }}">{{ message.content }}</div>
        {% endfor %}
    </div>

    <div class="input-container">
        <div class="input-box">
            <input type="text" id="user-input" placeholder="Chatea con Arpa" autofocus>
            <button id="send-button"><i class="fa fa-send"></i></button>
        </div>
    </div>
</body>
</html>

EOL
    
    cat > data/templates/data/excel_data.html << EOL
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Excel Data</title>
    <link rel="stylesheet" href="{% static 'dashStyle.css' %}">
</head>
<body>
    {% if stats %}
    <div class="stats-container">
        <h2>File Statistics</h2>
        <p>Filename: {{ stats.filename }}</p>
        <p>Total Rows: {{ stats.total_rows }}</p>
        <p>Total Value: {{ stats.total_value }}</p>
        <p>Average Value: {{ stats.average_value }}</p>
        <p>Null Values: {{ stats.null_values }}</p>
    </div>

    <div class="data-container">
        <table>
            <thead>
                <tr>
                    {% for column in columns %}
                    <th>{{ column }}</th>
                    {% endfor %}
                </tr>
            </thead>
            <tbody>
                {% for row in data %}
                <tr>
                    {% for column in columns %}
                    <td>{{ row|get_item:column }}</td>
                    {% endfor %}
                </tr>
                {% endfor %}
            </tbody>
        </table>
    </div>
    {% endif %}
</body>
</html>

EOL
}

createStatic() {
    echo -e "${YELLOW}🎨 Creating Static Files${NC}"
    mkdir -p static
    touch static/dashStyle.css
    cat > static/dashStyle.css << EOL
body {
    margin: 0;
    font-family: Arial, sans-serif;
    background-color: #f0f2f5;
}

.topnav-container {
    display: flex;
    justify-content: space-between;
    align-items: center;
    background-color: white;
    padding: 10px 20px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.logoIN {
    text-decoration: none;
    color: #0b00a2;
    font-size: 24px;
    font-weight: bold;
}

.topnav a {
    color: black;
    text-decoration: none;
    padding: 10px 15px;
    font-size: 20px;
}

.column {
    float: left;
    width: 25%;
    padding: 0 10px;
    margin-top: 20px;
}

.card {
    background-color: white;
    padding: 20px;
    margin: 10px;
    border-radius: 10px;
    box-shadow: 0 4px 8px rgba(0,0,0,0.1);
}

.card a {
    text-decoration: none;
    color: #333;
    font-size: 18px;
    display: flex;
    align-items: center;
    justify-content: space-between;
}

.titles {
    margin: 0 10px;
}

.error-message {
    background-color: #ffebee;
    color: #c62828;
    padding: 10px;
    margin: 10px;
    border-radius: 4px;
}

/* static/css/file.css */
body {
    margin: 0;
    font-family: Arial, sans-serif;
    background-color: #f0f2f5;
}

.topnav-container {
    display: flex;
    justify-content: space-between;
    align-items: center;
    background-color: white;
    padding: 10px 20px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.dashboard {
    padding: 20px;
}

.stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 20px;
    margin-top: 20px;
}

.stat-card {
    background-color: white;
    padding: 20px;
    border-radius: 10px;
    box-shadow: 0 4px 8px rgba(0,0,0,0.1);
}

.error {
    background-color: #ffebee;
    color: #c62828;
    padding: 10px;
    margin: 10px;
    border-radius: 4px;
}

input[type="file"] {
    width: 100%;
    padding: 10px;
    border: 1px solid #ddd;
    border-radius: 4px;
}

input[type="submit"] {
    background-color: #0b00a2;
    color: white;
    padding: 10px 20px;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    width: 100%;
}

/* static/css/chat.css */
body {
    margin: 0;
    font-family: Arial, sans-serif;
    background-color: #f0f2f5;
    height: 100vh;
    display: flex;
    flex-direction: column;
}

.chat-container {
    flex-grow: 1;
    overflow-y: auto;
    padding: 20px;
    margin-bottom: 70px;
}

.message {
    margin: 10px;
    padding: 15px;
    border-radius: 10px;
    max-width: 70%;
}

.user {
    background-color: #e3f2fd;
    margin-left: auto;
}

.assistant {
    background-color: #f5f5f5;
    margin-right: auto;
}

.input-container {
    position: fixed;
    bottom: 0;
    width: 100%;
    padding: 10px;
    background-color: white;
    box-shadow: 0 -2px 10px rgba(0,0,0,0.1);
}

.input-box {
    display: flex;
    max-width: 800px;
    margin: 0 auto;
    padding: 0 20px;
}

#user-input {
    flex-grow: 1;
    padding: 10px;
    border: 1px solid #ddd;
    border-radius: 20px;
    margin-right: 10px;
}

#send-button {
    background-color: #0b00a2;
    color: white;
    border: none;
    border-radius: 50%;
    width: 40px;
    height: 40px;
    cursor: pointer;
}

/* static/css/data.css */
body {
    margin: 0;
    padding: 20px;
    font-family: Arial, sans-serif;
    background-color: #f0f2f5;
}

.stats-container {
    background-color: white;
    padding: 20px;
    border-radius: 10px;
    box-shadow: 0 4px 8px rgba(0,0,0,0.1);
    margin-bottom: 20px;
}

.data-container {
    background-color: white;
    padding: 20px;
    border-radius: 10px;
    box-shadow: 0 4px 8px rgba(0,0,0,0.1);
    overflow-x: auto;
}

table {
    width: 100%;
    border-collapse: collapse;
}

th, td {
    padding: 12px;
    text-align: left;
    border-bottom: 1px solid #ddd;
}

th {
    background-color: #f8f9fa;
    font-weight: bold;
}

tr:hover {
    background-color: #f5f5f5;

EOL
}

main() {
    echo -e "${YELLOW}🔧 Django Project Initialization${NC}"
    
    createStructure
    generateGitignore
    generateEnv
    updateSettings
    createUrls
    createViews
    createAppConfigs
    createTemplates
    createStatic
    
    python manage.py makemigrations
    python manage.py migrate
    
    chmod 600 .env
    source .venv/bin/activate
    
    echo -e "${GREEN}🎉 Django project is ready! Run 'python manage.py runserver' to start.${NC}"
}

main
source .venv/bin/activate