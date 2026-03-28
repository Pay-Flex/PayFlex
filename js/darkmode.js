
document.addEventListener("DOMContentLoaded", () => {
    const darkModeToggle = document.getElementById("darkModeToggle");
    const body = document.body;
    
    // Check local storage for preference
    const isDarkMode = localStorage.getItem("darkMode") === "enabled";
    if (isDarkMode) {
        body.classList.add("dark-theme");
        if(darkModeToggle) darkModeToggle.innerHTML = '<i class="fas fa-sun" style="font-size: 1.1rem;"></i>';
    }

    if (darkModeToggle) {
        darkModeToggle.addEventListener("click", () => {
            body.classList.toggle("dark-theme");
            if (body.classList.contains("dark-theme")) {
                localStorage.setItem("darkMode", "enabled");
                darkModeToggle.innerHTML = '<i class="fas fa-sun" style="font-size: 1.1rem;"></i>';
            } else {
                localStorage.setItem("darkMode", "disabled");
                darkModeToggle.innerHTML = '<i class="fas fa-moon" style="font-size: 1.1rem;"></i>';
            }
        });
    }
});
