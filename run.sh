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
    pip install django python-dotenv pandas openpyxl  plotly
    
    # Create Django project
    django-admin startproject config .
    python manage.py startapp dashboard
    python manage.py startapp files
    python manage.py startapp data
    
    # Create additional directories
    mkdir -p {media/uploads,media/downloads,static}
    
    
    # Create other files
    touch .env
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

    mkdir -p data/templatetags
    touch data/templatetags/data_filters.py
    cat > data/templatetags/data_filters.py << EOL
from django import template

register = template.Library()

@register.filter
def get_item(dictionary, key):
    return dictionary.get(key)

EOL
}

    

createViews() {
    # Dashboard Views
    cat > dashboard/views.py << EOL
from django.shortcuts import render
from django.http import StreamingHttpResponse
import time
import json

def dashboard(request):
    return render(request, 'dashboard/dashboard.html')

def files(request):
    return render(request, 'dashboard/files.html')


def chat(request):
    if request.method == 'GET':  # For initial page load
        return render(request, 'dashboard/chat.html')

    return StreamingHttpResponse(stream_generator(request), content_type='text/event-stream')

def stream_generator(request):
    while True:
        # Replace this with your actual chat logic (e.g., database queries, external API calls)
        time.sleep(2)  # Simulate some delay

        user_message = request.GET.get('message') # Get the last user input

        if user_message:
          message = {"role": "chat", "content": f"You said: {user_message}"}
          yield f"data: {json.dumps(message)}\n\n"
EOL

    # Files Views
    cat > files/views.py << EOL
from django.shortcuts import render, redirect
import pandas as pd
from django.contrib import messages
import plotly.express as px
import plotly.utils
import json
import numpy as np 

def read_excel(request):
    # Initialize context with has_data as False by default
    context = {'has_data': False}
    
    if request.method == 'POST':
        if 'file' not in request.FILES:
            messages.error(request, 'Please upload a file')
            return render(request, 'files/files.html', context)
        
        file = request.FILES['file']
        
        if not file.name.lower().endswith(('.xls', '.xlsx', '.xlsm', '.xlsb')):
            messages.error(request, 'Invalid file type. Please upload an Excel file.')
            return render(request, 'files/files.html', context)
        
        try:
            # Read the Excel file
            df = pd.read_excel(file)
            
            # Basic statistics
            stats = {
                'filename': file.name,
                'total_rows': len(df),
                'total_columns': len(df.columns),
                'null_values': df.isnull().sum().sum(),
                'numeric_columns': len(df.select_dtypes(include=['int64', 'float64']).columns),
                'text_columns': len(df.select_dtypes(include=['object']).columns)
            }
            
            # Add summary statistics for numeric columns
            numeric_stats = {}
            for col in df.select_dtypes(include=['int64', 'float64']).columns:
                numeric_stats[col] = {
                    'mean': df[col].mean(),
                    'median': df[col].median(),
                    'std': df[col].std(),
                    'min': df[col].min(),
                    'max': df[col].max()
                }
            
            # Create visualizations using plotly
            visualizations = {}
            
            # Histogram for numeric columns
            for col in df.select_dtypes(include=['int64', 'float64']).columns[:3]:  # Limit to first 3 numeric columns
                fig = px.histogram(df, x=col, title=f'Distribution of {col}')
                visualizations[col] = json.dumps(fig.to_dict())
            
            # Prepare table data
            table_data = df.head(10).to_dict('records')  # Show first 10 rows
            columns = df.columns.tolist()
            
            # Update context with all the data
            context.update({
                'stats': stats,
                'numeric_stats': numeric_stats,
                'visualizations': visualizations,
                'table_data': table_data,
                'columns': columns,
                'has_data': True  # Set this to True since we have data
            })

            # Convert numpy int64 to native Python int
            stats['null_values'] = int(stats['null_values'])

            # Convert numeric_stats values to regular Python types
            for col, col_stats in numeric_stats.items():
                for stat_name, stat_value in col_stats.items():
                    numeric_stats[col][stat_name] = float(stat_value) if isinstance(stat_value, (np.floating, np.integer)) else stat_value
            
            # Print debug information
            print("Context keys:", context.keys())
            print("Has data:", context['has_data'])
            print("Number of rows in table_data:", len(context['table_data']))
            
            # Store data in the session
            request.session['excel_data'] = {
                'stats': stats,
                'numeric_stats': numeric_stats,
                'visualizations': visualizations,  # Make sure visualizations are serializable
                'table_data': table_data,
                'columns': columns,
                'has_data': True
            }
            print(request.session['excel_data'])


            return redirect('data:excel_data')
            
        except Exception as e:
            messages.error(request, f'Error processing file: {str(e)}')
            return render(request, 'files/files.html', context)
    
    return render(request, 'files/files.html', context)
EOL

    # Data Views
    cat > data/views.py << EOL
from django.shortcuts import render

def excel_data(request):
    context = request.session.get('excel_data', {'has_data': False})  # Retrieve from session
    
    # Delete after retrieving so you don't see old data on refresh.
    if 'excel_data' in request.session:
        del request.session['excel_data']
        
    print(context)
    return render(request, 'data/excel_data.html', context)
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
            <button id="send-button"> <i class="fa fa-send"></i></button>
        </div>
    </div>
    <script>
        const chatContainer = document.getElementById('chat-container');
        const userInput = document.getElementById('user-input');
        const sendButton = document.getElementById('send-button');
  
  
        // Function to create message element
        function createMessageElement(role, content) {
            const messageDiv = document.createElement('div');
            messageDiv.classList.add('message', role);
            messageDiv.textContent = content;
            chatContainer.appendChild(messageDiv);
            chatContainer.scrollTop = chatContainer.scrollHeight;
          }
  
  
        sendButton.addEventListener('click', () => {
          const message = userInput.value;
  
          if (message.trim() !== '') {
               createMessageElement('user', message);
  
              let url = new URL("{% url 'dashboard:chat' %}");
              let params = new URLSearchParams(url.search);
              params.set('message', message);
              url.search = params.toString();
  
  
  
              const eventSource = new EventSource(url.toString());
  
              eventSource.onmessage = (event) => {
                  const data = JSON.parse(event.data);
                  createMessageElement(data.role, data.content);
              };
  
  
              userInput.value = ''; // Clear the input field
          }
  
        });
  
        userInput.addEventListener('keyup', (event) => {
            if (event.key === 'Enter') {
              sendButton.click(); // Simulate a click on the send button
            }
        });
  
      </script>
</body>
</html>

EOL
    
    cat > data/templates/data/excel_data.html << EOL
{% load data_filters %}
{% load static %}
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Excel Analysis</title>
    <link rel="stylesheet" href="{% static 'dashStyle.css' %}">
    <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
</head>
<body>
    <div class="topnav-container">
        <div>
            <a href="{% url 'dashboard:dashboard' %}" class="logoIN">
                <div class="nomPag">Analysis Results</div>
            </a>
        </div>
        <div class="topnav">
            <a href="{% url 'dashboard:files' %}"><i class="fa fa-upload"></i></a>
            <a href="{% url 'dashboard:dashboard' %}"><i class="fa fa-bar-chart"></i></a>
        </div>
    </div>

    {% if has_data %}
        <!-- File Statistics -->
        <div class="stat-card">
            <h2>File Overview</h2>
            <div class="stats-grid">
                <div class="stat-item">
                    <p><strong>Filename:</strong> {{ stats.filename }}</p>
                    <p><strong>Total Rows:</strong> {{ stats.total_rows }}</p>
                    <p><strong>Total Columns:</strong> {{ stats.total_columns }}</p>
                    <p><strong>Null Values:</strong> {{ stats.null_values }}</p>
                    <p><strong>Numeric Columns:</strong> {{ stats.numeric_columns }}</p>
                    <p><strong>Text Columns:</strong> {{ stats.text_columns }}</p>
                </div>
            </div>
        </div>

        <!-- Numeric Statistics -->
        {% if numeric_stats %}
        <div class="stat-card">
            <h2>Numeric Column Statistics</h2>
            {% for column, stats in numeric_stats.items %}
            <div class="column-stats">
                <h3>{{ column }}</h3>
                <p>Mean: {{ stats.mean|floatformat:2 }}</p>
                <p>Median: {{ stats.median|floatformat:2 }}</p>
                <p>Standard Deviation: {{ stats.std|floatformat:2 }}</p>
                <p>Min: {{ stats.min|floatformat:2 }}</p>
                <p>Max: {{ stats.max|floatformat:2 }}</p>
            </div>
            {% endfor %}
        </div>
        {% endif %}

        <!-- Visualizations -->
        {% if visualizations %}
        <div class="visualizations-container">
            <h2>Data Visualizations</h2>
            {% for column, plot_data in visualizations.items %}
            <div class="plot-container" id="plot-{{ forloop.counter }}"></div>
            <script>
                var plotData = {{ plot_data|safe }};
                Plotly.newPlot('plot-{{ forloop.counter }}', plotData.data, plotData.layout);
            </script>
            {% endfor %}
        </div>
        {% endif %}

        <!-- Data Preview -->
        <div class="data-preview">
            <h2>Data Preview (First 10 rows)</h2>
            <div class="table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            {% for column in columns %}
                            <th>{{ column }}</th>
                            {% endfor %}
                        </tr>
                    </thead>
                    <tbody>
                        {% for row in table_data %}
                        <tr>
                            {% for column in columns %}
                            <td>{{ row|get_item:column }}</td>
                            {% endfor %}
                        </tr>
                        {% endfor %}
                    </tbody>
                </table>
            </div>
        </div>
    {% else %}
        <div class="error-message">
            No data available. Please upload an Excel file.
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

.visualizations-container {
    margin: 20px 0;
    padding: 20px;
    background: white;
    border-radius: 8px;
    box-shadow: 0 4px 8px rgba(0,0,0,0.1);
}

.plot-container {
    margin: 20px 0;
    height: 400px;
}

.column-stats {
    margin: 15px 0;
    padding: 15px;
    border-bottom: 1px solid #eee;
}

.table-container {
    overflow-x: auto;
    margin: 20px 0;
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

    python3 -m venv .venv
    source .venv/bin/activate
    
    echo -e "${GREEN}🎉 Django project is ready!${NC}"

    python3 manage.py runserver
}

main