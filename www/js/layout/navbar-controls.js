// Navbar auto-hide functionality
document.addEventListener('DOMContentLoaded', function () {
    let lastScroll = 0;
    const navbar = document.querySelector('.navbar');

    if (!navbar) {
        console.log('Navbar not found');
        return;
    }
    console.log('Navbar controls initialized');

    window.addEventListener('scroll', () => {
        const currentScroll = window.pageYOffset;
        console.log('Scroll position:', currentScroll);

        if (currentScroll <= 0) {
            navbar.classList.remove('navbar-hidden');
            console.log('At top, showing navbar');
            return;
        }

        if (currentScroll > lastScroll && !navbar.classList.contains('navbar-hidden')) {
            // Scrolling down & navbar visible
            navbar.classList.add('navbar-hidden');
            console.log('Hiding navbar');
        } else if (currentScroll < lastScroll && navbar.classList.contains('navbar-hidden')) {
            // Scrolling up & navbar hidden
            navbar.classList.remove('navbar-hidden');
            console.log('Showing navbar');
        }

        lastScroll = currentScroll;
    });
}); 