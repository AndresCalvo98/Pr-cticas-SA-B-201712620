document.addEventListener('DOMContentLoaded', async () => {
    const userInfoSpan = document.getElementById('user-info');
    const btnRuta1 = document.getElementById('btn-ruta1');
    const btnRuta2 = document.getElementById('btn-ruta2');
    const resRuta1 = document.getElementById('res-ruta1');
    const resRuta2 = document.getElementById('res-ruta2');
    const logoutBtn = document.getElementById('logout-btn');

    // Cargar info del usuario
    try {
        const res = await fetch('/api/me');
        if (!res.ok) {
            window.location.href = '/'; // Redirigir si no hay sesion
            return;
        }
        const data = await res.json();
        userInfoSpan.innerHTML = `Hola, <strong>${data.user.name}</strong> (${data.user.role})`;
    } catch (error) {
        window.location.href = '/';
    }

    const testRoute = async (route, resultDiv) => {
        resultDiv.classList.remove('hidden');
        resultDiv.innerHTML = '<span class="text-yellow-400">Consultando...</span>';
        resultDiv.className = 'mt-4 p-3 rounded-lg text-sm font-mono bg-black/30 border border-slate-700';

        try {
            const res = await fetch(route);
            const data = await res.json();

            if (res.ok) {
                resultDiv.innerHTML = `<span class="text-green-400">✅ 200 OK</span><br><span class="text-slate-300">${JSON.stringify(data)}</span>`;
                resultDiv.classList.add('border-green-500/50');
            } else {
                resultDiv.innerHTML = `<span class="text-red-400">❌ ${res.status} Error</span><br><span class="text-slate-300">${JSON.stringify(data)}</span>`;
                resultDiv.classList.add('border-red-500/50');
            }
        } catch (error) {
            resultDiv.innerHTML = `<span class="text-red-400">❌ Error de conexión</span>`;
        }
    };

    btnRuta1.addEventListener('click', () => testRoute('/api/ruta1', resRuta1));
    btnRuta2.addEventListener('click', () => testRoute('/api/ruta2', resRuta2));

    logoutBtn.addEventListener('click', async () => {
        await fetch('/api/logout', { method: 'POST' });
        window.location.href = '/';
    });
});
