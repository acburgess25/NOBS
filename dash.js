// Mock data simulation for a highly active AI business

function updateComputeData() {
    const vramUsage = Math.floor(Math.random() * 100) + 1; // Random VRAM usage between 1% and 100%
    const tokenSpeed = Math.floor(Math.random() * 50) + 1; // Random token generation speed between 1 t/s and 50 t/s
    document.getElementById('vram-usage').textContent = `${vramUsage}%`;
    document.getElementById('token-speed').textContent = `${tokenSpeed} t/s`;
}

function updateAPIData() {
    const customerRequests = Math.floor(Math.random() * 600) + 1; // Random customer requests between 1 and 600
    document.getElementById('customer-requests').textContent = customerRequests;
}

setInterval(updateComputeData, 5000); // Update compute data every 5 seconds
setInterval(updateAPIData, 5000); // Update API data every 5 seconds

// Initial update
updateComputeData();
updateAPIData();
