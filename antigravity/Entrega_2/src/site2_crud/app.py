from flask import Flask, render_template, request, redirect, url_for, flash
import sqlite3
import os

app = Flask(__name__)
app.secret_key = 'supersecretkey'
DB_NAME = 'database.db'

def init_db():
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT NOT NULL UNIQUE,
            role TEXT NOT NULL
        )
    ''')
    conn.commit()
    conn.close()

@app.route('/')
def index():
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users")
    users = cursor.fetchall()
    conn.close()
    return render_template('index.html', users=users)

@app.route('/create', methods=('GET', 'POST'))
def create():
    if request.method == 'POST':
        name = request.form['name']
        email = request.form['email']
        role = request.form['role']

        if not name or not email or not role:
            flash('Todos los campos son obligatorios')
        else:
            try:
                conn = sqlite3.connect(DB_NAME)
                cursor = conn.cursor()
                cursor.execute("INSERT INTO users (name, email, role) VALUES (?, ?, ?)", (name, email, role))
                conn.commit()
                conn.close()
                flash('Usuario creado exitosamente')
                return redirect(url_for('index'))
            except sqlite3.IntegrityError:
                flash('El email ya existe')
            except Exception as e:
                flash(f'Error: {e}')

    return render_template('create.html')

@app.route('/update/<int:id>', methods=('GET', 'POST'))
def update(id):
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE id = ?", (id,))
    user = cursor.fetchone()
    conn.close()

    if user is None:
        flash('Usuario no encontrado')
        return redirect(url_for('index'))

    if request.method == 'POST':
        name = request.form['name']
        email = request.form['email']
        role = request.form['role']

        if not name or not email or not role:
            flash('Todos los campos son obligatorios')
        else:
            try:
                conn = sqlite3.connect(DB_NAME)
                cursor = conn.cursor()
                cursor.execute("UPDATE users SET name = ?, email = ?, role = ? WHERE id = ?", (name, email, role, id))
                conn.commit()
                conn.close()
                flash('Usuario actualizado exitosamente')
                return redirect(url_for('index'))
            except sqlite3.IntegrityError:
                flash('El email ya existe')
            except Exception as e:
                flash(f'Error: {e}')

    return render_template('update.html', user=user)

@app.route('/delete/<int:id>', methods=('POST',))
def delete(id):
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    cursor.execute("DELETE FROM users WHERE id = ?", (id,))
    conn.commit()
    conn.close()
    flash('Usuario eliminado exitosamente')
    return redirect(url_for('index'))

if __name__ == '__main__':
    if not os.path.exists(DB_NAME):
        init_db()
    app.run(debug=True, host='0.0.0.0', port=5000)
