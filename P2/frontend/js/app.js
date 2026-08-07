document.addEventListener('DOMContentLoaded', () => {
    const loginForm = document.getElementById('login-form');
    const registerForm = document.getElementById('register-form');
    const showRegisterBtn = document.getElementById('show-register');
    const showLoginBtn = document.getElementById('show-login');
    const formSubtitle = document.getElementById('form-subtitle');
    const alertBox = document.getElementById('alert-box');

    const showAlert = (message, type = 'error') => {
        alertBox.textContent = message;
        alertBox.className = `mb-4 p-3 rounded-lg text-sm font-medium ${type === 'error' ? 'bg-red-500/20 text-red-200 border border-red-500/50' : 'bg-green-500/20 text-green-200 border border-green-500/50'}`;
        alertBox.classList.remove('hidden');
    };

    const hideAlert = () => {
        alertBox.classList.add('hidden');
    };

    showRegisterBtn.addEventListener('click', (e) => {
        e.preventDefault();
        hideAlert();
        loginForm.classList.add('hidden');
        registerForm.classList.remove('hidden');
        formSubtitle.textContent = 'Crea una nueva cuenta';
    });

    showLoginBtn.addEventListener('click', (e) => {
        e.preventDefault();
        hideAlert();
        registerForm.classList.add('hidden');
        loginForm.classList.remove('hidden');
        formSubtitle.textContent = 'Inicia sesión en tu cuenta';
    });

    loginForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        hideAlert();
        const email = document.getElementById('login-email').value;
        const password = document.getElementById('login-password').value;

        try {
            const res = await fetch('/api/login', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ email, password })
            });

            const data = await res.json();

            if (res.ok) {
                // Login exitoso, la cookie HTTP-only ya fue configurada por el backend
                showAlert('Login exitoso. Redirigiendo...', 'success');
                setTimeout(() => {
                    window.location.href = '/dashboard.html';
                }, 1000);
            } else {
                showAlert(data.error || 'Error en el login');
            }
        } catch (error) {
            showAlert('Error de conexión');
        }
    });

    registerForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        hideAlert();
        const name = document.getElementById('reg-name').value;
        const email = document.getElementById('reg-email').value;
        const password = document.getElementById('reg-password').value;
        const role = document.getElementById('reg-role').value;

        try {
            const res = await fetch('/api/register', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ name, email, password, role })
            });

            const data = await res.json();

            if (res.ok) {
                showAlert('Registro exitoso. Por favor inicia sesión.', 'success');
                registerForm.reset();
                setTimeout(() => {
                    showLoginBtn.click();
                }, 1500);
            } else {
                showAlert(data.error || 'Error en el registro');
            }
        } catch (error) {
            showAlert('Error de conexión');
        }
    });
});
