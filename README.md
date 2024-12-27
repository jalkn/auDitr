## Installation

1. **Clone the repository:**
```bash
git clone https://github.com/jalknToth/auDitr.git
```

2. **Run the setup script:**
```bash
chmod +x run.sh
./run.sh
```
The script will create:
- 🔧 Auditor views
- 🔧 Auditor urls
- 🔧 Auditor settings
- 🔧 Persons urls
- 🔧 Persons models
- 🔧 Persons views
- 🔧 All Templates

3. **Open the app**
```
python3 manage.py runserver
```
To create a admin user run
```
python3 manage.py createsuperuser
```
Then open http://127.0.0.1:8000/admin

<table>
  <tr>
    <td><img src="screenshots/login.png" alt="login" width="200px"></td>
    <td><img src="screenshots/admin.png" alt="admin" width="200px"></td>
  </tr>
</table>

