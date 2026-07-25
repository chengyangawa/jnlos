(function() {
    'use strict';

    // ---- Toast ----
    var Toast = {
        container: document.getElementById('js-toast-container'),
        show: function(message) {
            if (!this.container) return;
            var toast = document.createElement('div');
            toast.className = 'toast';
            toast.textContent = message;
            this.container.appendChild(toast);
            requestAnimationFrame(function() {
                toast.classList.add('toast--show');
            });
            setTimeout(function() {
                toast.classList.remove('toast--show');
                setTimeout(function() {
                    if (toast.parentNode) toast.parentNode.removeChild(toast);
                }, 300);
            }, 2800);
        }
    };

    // ---- 导航栏自动隐藏 ----
    var NavControl = {
        el: document.getElementById('js-site-nav'),
        lastScrollY: window.scrollY,
        ticking: false,
        hideThreshold: 150,

        init: function() {
            if (!this.el) return;
            var self = this;

            window.addEventListener('scroll', function() {
                if (!self.ticking) {
                    window.requestAnimationFrame(function() {
                        self.handleScroll();
                        self.ticking = false;
                    });
                    self.ticking = true;
                }
            });

            this.el.classList.remove('site-nav--hidden');
        },

        handleScroll: function() {
            var currentScrollY = window.scrollY;
            var windowHeight = window.innerHeight;
            var documentHeight = document.documentElement.scrollHeight;
            var distanceToBottom = documentHeight - (currentScrollY + windowHeight);

            var isNearBottom = distanceToBottom < this.hideThreshold;
            var isScrollingDown = currentScrollY > this.lastScrollY;

            if (isNearBottom && isScrollingDown && currentScrollY > 100) {
                this.el.classList.add('site-nav--hidden');
            } else {
                this.el.classList.remove('site-nav--hidden');
            }

            this.lastScrollY = currentScrollY;
        }
    };

    // ---- 初始化 ----
    NavControl.init();

})();
