// Add some subtle interactivity
document.addEventListener('DOMContentLoaded', function() {
    // Glitch effect enhancement
    const glitchElement = document.querySelector('.glitch');
    
    setInterval(() => {
        if (Math.random() < 0.1) {
            glitchElement.style.textShadow = `
                ${Math.random() * 10 - 5}px ${Math.random() * 10 - 5}px 0 #ff0040,
                ${Math.random() * 10 - 5}px ${Math.random() * 10 - 5}px 0 #00ff40,
                0 0 15px #00d4ff
            `;
            
            setTimeout(() => {
                glitchElement.style.textShadow = '0 0 5px #00d4ff, 0 0 10px #00d4ff, 0 0 15px #00d4ff';
            }, 50);
        }
    }, 1000);
    
    // Parallax effect for hero section
    window.addEventListener('scroll', () => {
        const scrolled = window.pageYOffset;
        const hero = document.querySelector('.hero');
        const rate = scrolled * -0.5;
        hero.style.transform = `translateY(${rate}px)`;
    });
});
