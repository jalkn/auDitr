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
    <link rel="stylesheet" href="{% static 'files.css' %}">
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
    <link rel="stylesheet" href="{% static 'chat.css' %}">
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
@import url('https://fonts.googleapis.com/css2?family=Open+Sans&display=swap');

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  background-color: rgb(255, 255, 255);
  font-family: 'Open Sans', sans-serif;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  padding: 20px;
  
}

.logoIN {
  cursor: pointer;
  margin: 1rem auto;
  width: 40px;
  height: 40px;
  background-color: #0b00a2;
  position: relative;
  display: inline-flex;
  text-decoration:none;
  border-radius: 8px;
}
.logoIN::before {
  content: "";
  width: 40px;
  height: 40px;
  border-radius: 50%;
  position: absolute;
  top: 30%;
  left: 70%;
  transform: translate(-50%, -50%);
  background-image: linear-gradient(to right, 
      #ffffff 2px, transparent 1.5px,
      transparent 1.5px, #ffffff 1.5px,
      #ffffff 2px, transparent 1.5px);
  background-size: 4px 100%; 
}

/*
.logoIN {
  cursor: pointer;
  margin-bottom: 20px;
  width: 40px;
  height: 40px;
  background-color: #0b00a2;
  position: relative;
  display: inline-flex;
  text-decoration:none
}

.logoIN::before {
  content: "";
  display: block;
  width: 40px;
  height: 40px;
  background-color: rgb(255, 255, 255);
  border-radius: 50%;
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
}
*/
.nomPag{
  margin-left: 100px;
  padding: 20px 55px;
  text-decoration:none;
  margin-left: 2px;
  color: #0b00a2;
}

.material-icons{
  color: #0b00a2;

}

.topnav i{
  color: #0b00a2;
  font-size: 25px;
}

.topnav-container{
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px;
  top: 0;
}

.topnav a {
  display: inline-block;
  text-align: center;
  padding: 5px 5px;
  text-decoration: none;
  margin-left: 2px;
}

.titles {
  font-family: 'Open Sans', sans-serif;
  font-size: 15px;
  margin: 20px;
  color: #0b00a2;
}

.column {
  float: left;
  width: 100%;
  padding: 0 10px;
  margin-bottom: 20px;
}

.search-container {
  position: relative;
}

.search-container i {
  position: absolute;
  left: 25px;
  top: 50%;
  transform: translateY(-50%);
}

.search-container input {
  padding-left: 40px;
  width: 100%;
  border: 2px solid #ccc;
  box-sizing: border-box;
  border-radius: 10px;
  padding: 20px 60px;
  font-size: 16px;
  font-family: 'Open Sans', sans-serif;
}

#tabla {
  width: 100%;
  font-size: 16px;
  font-family: 'Open Sans', sans-serif;
  padding: 0 55px;
}

#tabla th, #tabla td {
  text-align: left;
  padding: 0.8rem;
}


.row {margin: 0 -5px;}

.row:after {
  content: "";
  display: table;
  clear: both;
}

@media screen and (max-width: 600px) {
  .column {
    width: 100%;
    display: block;
    margin-bottom: 20px;
  }
}

.card {
  display: flex;
  stroke-width: 3px;
  flex-direction: column;
  align-items: center;
  box-shadow: 0 4px 8px 0 rgba(0, 0, 0, 0.2);
  padding: 25px;
  text-align: center;
  background-color: rgb(255, 255, 255);
  border-radius: 10px;
  position: relative;
  width: 100%;
  border: 1px solid #c8c8c8;
  
}

.card a{
  font-size: 1rem;
  color: #0b00a2;
  display: flex;
  left: 0;
  width: 100%;
  text-decoration: none;
  justify-content: space-between;
  font-family: 'Open Sans', sans-serif;
}

.card h2{
  font-family: 'Open Sans', sans-serif;
  right: 0;
  top: 0;
  position: absolute;

}

@media (max-width: 480px) {
  .logo {
    margin-top: 100px;
  }
  .container {
    width: 95%;
  }
  .form {
    padding: 15px;
  }
}

@media (max-width: 768px) { /* Adjust the breakpoint as needed */
  .hidden-on-medium {
    display: none;
  }

  .header th:first-child { /* Nombre */
    width: 60%; /* Adjust widths as needed for two-column layout */
  }
  .header th:nth-child(2) { /* Compañía */
    width: 40%;
  }


}

EOL

    touch static/chat.css
    cat > static/chat.css << EOL
@import url('https://fonts.googleapis.com/css2?family=Open+Sans&display=swap');

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  background-color: #ffffff;
  font-family: 'Open Sans', sans-serif;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  padding: 20px;
  margin: 0;
}

.logoIN {
  cursor: pointer;
  margin: 1rem auto;
  width: 40px;
  height: 40px;
  background-color: #0b00a2;
  position: relative;
  display: inline-flex;
  text-decoration:none;
  border-radius: 8px;
}
.logoIN::before {
  content: "";
  width: 40px;
  height: 40px;
  border-radius: 50%;
  position: absolute;
  top: 30%;
  left: 70%;
  transform: translate(-50%, -50%);
  background-image: linear-gradient(to right, 
      #ffffff 2px, transparent 1.5px,
      transparent 1.5px, #ffffff 1.5px,
      #ffffff 2px, transparent 1.5px);
  background-size: 4px 100%; 
}

.logo:hover {
  background-color: #1d10d3;
}

.nomPag{
  margin-left: 100px;
  padding: 20px 55px;
  text-decoration:none;
  margin-left: 2px;
  color: #0b00a2;
}

.material-icons{
  color: #0b00a2;
}

.topnav i{
  color: #0b00a2;
  font-size: 25px;
}

.topnav-container{
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px;
  top: 0;
}

.topnav a {
  display: inline-block;
  text-align: center;
  padding: 5px 5px;
  text-decoration: none;
  margin-left: 2px;
}

.titles {
  font-family: 'Open Sans', sans-serif;
  font-size: 15px;
  margin: 20px;
  color: #0b00a2;
}

.column {
  float: left;
  width: 100%;
  padding: 0 10px;
  margin-bottom: 20px;
}

.search-container {
  position: relative;
}

.search-container i {
  position: absolute;
  left: 25px;
  top: 50%;
  transform: translateY(-50%);
}

.search-container input {
  padding-left: 40px;
  width: 100%;
  border: 2px solid #ccc;
  box-sizing: border-box;
  border-radius: 10px;
  padding: 20px 60px;
  font-size: 16px;
  font-family: 'Open Sans', sans-serif;
}

#tabla {
  width: 100%;
  font-size: 16px;
  font-family: 'Open Sans', sans-serif;
  padding: 0 55px;
}

#tabla th, #tabla td {
  text-align: left;
  padding: 0.8rem;
}


.row {margin: 0 -5px;}

.row:after {
  content: "";
  display: table;
  clear: both;
}

@media screen and (max-width: 600px) {
  .column {
    width: 100%;
    display: block;
    margin-bottom: 20px;
  }
}

.card {
  display: flex;
  stroke-width: 3px;
  flex-direction: column;
  align-items: center;
  box-shadow: 0 4px 8px 0 rgba(0, 0, 0, 0.2);
  padding: 25px;
  text-align: center;
  background-color: #ffffff;
  border-radius: 10px;
  position: relative;
  width: 100%;
  border: 1px solid #c8c8c8;
  
}

.card a{
  font-size: 1rem;
  color: #0b00a2;
  display: flex;
  left: 0;
  width: 100%;
  text-decoration: none;
  justify-content: space-between;
  font-family: 'Open Sans', sans-serif;
}

.card h2{
  font-family: 'Open Sans', sans-serif;
  right: 0;
  top: 0;
  position: absolute;

}

@media (max-width: 480px) {
  .logo {
    margin-top: 100px;
  }
  .container {
    width: 95%;
  }
  .form {
    padding: 15px;
  }
}

@media (max-width: 768px) { /* Adjust the breakpoint as needed */
  .hidden-on-medium {
    display: none;
  }

  .header th:first-child { /* Nombre */
    width: 60%; /* Adjust widths as needed for two-column layout */
  }
  .header th:nth-child(2) { /* Compañía */
    width: 40%;
  }
}

.chat-container {
  width: 100%;
  background-color: white;
  border-radius: 10px;
  padding: 20px;
  margin-top: 20px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}
.message {
  margin-bottom: 15px;
  padding: 10px;
  border-radius: 6px;
}
.user {
  font-family: 'Open Sans', sans-serif;
  background-color: #e9e9e9;
  text-align: right;
}
.chat {
  font-family: 'Open Sans', sans-serif;
  background-color: #deecf2;
  text-align: left;
}
.input-container {
  width: 100%;
  margin-top: 20px;
}
.input-box {
  display: flex;
  border: 1px solid #ccc;
  border-radius: 6px; 
  overflow: hidden; 
}
.input-box input {
  flex-grow: 1;
  padding: 10px;
  border: none;
  outline: none;
  border-radius: 25px 0 0 25px;  
}
.input-box button {
  background-color: #0b00a2; 
  color: white;
  border: none;
  padding: 10px 15px;
  cursor: pointer;
  border-radius: 0 6px 6px 0; 
  transition: background-color 0.3s ease; 
}
.input-box button:hover {
  background-color: #1d10d3; 
}
EOL

    touch static/files.css
    cat > static/files.css <<EOL
@import url('https://fonts.googleapis.com/css2?family=Open+Sans&display=swap');

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  background-color: rgb(255, 255, 255);
  font-family: 'Open Sans', sans-serif;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  padding: 20px;
  
}

.logoIN {
  cursor: pointer;
  margin: 1rem auto;
  width: 40px;
  height: 40px;
  background-color: #0b00a2;
  position: relative;
  display: inline-flex;
  text-decoration:none;
  border-radius: 8px;
}
.logoIN::before {
  content: "";
  width: 40px;
  height: 40px;
  border-radius: 50%;
  position: absolute;
  top: 30%;
  left: 70%;
  transform: translate(-50%, -50%);
  background-image: linear-gradient(to right, 
      #ffffff 2px, transparent 1.5px,
      transparent 1.5px, #ffffff 1.5px,
      #ffffff 2px, transparent 1.5px);
  background-size: 4px 100%; 
}

.nomPag{
  margin-left: 100px;
  padding: 20px 55px;
  text-decoration:none;
  margin-left: 2px;
  color: #0b00a2;
}

.material-icons{
  color: #0b00a2;

}

.topnav i{
  color: #0b00a2;
  font-size: 25px;
}

.topnav-container{
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px;
  top: 0;
}

.topnav a {
  display: inline-block;
  text-align: center;
  padding: 5px 5px;
  text-decoration: none;
  margin-left: 2px;
}

@media screen and (max-width: 600px) {
  .column {
    width: 100%;
    display: block;
    margin-bottom: 20px;
  }
}

@media (max-width: 480px) {
  .logo {
    margin-top: 100px;
  }
  .container {
    width: 95%;
  }
  .form {
    padding: 15px;
  }
}

@media (max-width: 768px) { /* Adjust the breakpoint as needed */
  .hidden-on-medium {
    display: none;
  }

  .header th:first-child { /* Nombre */
    width: 60%; /* Adjust widths as needed for two-column layout */
  }
  .header th:nth-child(2) { /* Compañía */
    width: 40%;
  }
}
.dashboard {
    width: 100%;
    margin: 0 auto;
}
.header {
    background: white;
    padding: 20px;
    box-shadow: 0 4px 8px 0 rgba(0, 0, 0, 0.2);
    border-radius: 8px;
    margin-bottom: 20px;
    border: 1px solid #c8c8c8;
}
.stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
    gap: 20px;
    margin-bottom: 20px;
    
}
/* Or display them inline within the card: */
/* .stat-item {
display: inline-block;
margin-right: 10px;
} 
*/
.stat-card {
    background: white;
    padding: 20px;
    border-radius: 8px;
    box-shadow: 0 4px 8px 0 rgba(0, 0, 0, 0.2);
    border: 1px solid #c8c8c8;
}
.stat-title {
    color: #6b7280;
    font-size: 0.875rem;
    margin-bottom: 8px;
}
.stat-value {
    font-size: 1.5rem;
    font-weight: 600;
    color: #111827;
}
.chart-container {
    background: white;
    padding: 20px;
    border-radius: 8px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    margin-bottom: 20px;
}
.data-table {
    width: 100%;
    border-collapse: collapse;
    background: white;
    border-radius: 8px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    border: 1px solid #c8c8c8;
}
.data-table th, .data-table td {
    padding: 12px;
    text-align: left;
    border-bottom: 1px solid #e5e7eb;
}
.data-table th {
    background: #f9fafb;
    font-weight: 500;
}
.data-table tr:last-child td {
    border-bottom: none;
}

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
    
    echo -e "${GREEN}🎉 Django project is ready! Run 'python manage.py runserver' to start.${NC}"
}

main