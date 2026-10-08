(function () {
  const {
    ensureDatabase,
    getCurrentUser,
    registerUser,
    loginUser,
    requestPasswordReset,
    updatePassword,
    socialLogin,
    clearCurrentUser
  } = window.MRCo;

  function updateAuthUI() {
    const currentUser = getCurrentUser();
    const authButtons = document.querySelectorAll('[data-auth]');
    const userStatus = document.querySelector('[data-user-status]');
    const adminLink = document.querySelector('[data-admin-link]');

    if (authButtons.length) {
      authButtons.forEach((button) => {
        const isVisible = !currentUser;
        button.style.display = isVisible ? 'inline-flex' : 'none';
      });
    }

    if (userStatus) {
      if (currentUser) {
        userStatus.innerHTML = `
          <span class="user-pill">Hi, ${currentUser.name}</span>
          <button class="nav-btn light" type="button" data-logout>Log out</button>
        `;
      } else {
        userStatus.innerHTML = '';
      }
    }

    if (adminLink) {
      adminLink.style.display = currentUser && currentUser.role === 'admin' ? 'inline-flex' : 'none';
    }

    // The cart replaces the auth buttons only after a user is authenticated.
    window.MRCO_CART?.refresh();
  }

  function buildAuthModal() {
    if (document.getElementById('authModal')) {
      return;
    }

    const modalMarkup = `
      <div id="authModal" class="modal hidden" aria-modal="true" role="dialog">
        <div class="modal-content">
          <button class="modal-close" type="button" data-close-auth aria-label="Close authentication form">&times;</button>
          <div class="auth-intro">
            <p class="eyebrow">MAYOR RIDE CO.</p>
            <h2 class="auth-title">Welcome back</h2>
            <p class="auth-subtitle">Sign in to manage your account and keep your next ride moving.</p>
          </div>
          <div class="auth-tabs">
            <button class="auth-tab active" type="button" data-auth-mode="login">Login</button>
            <button class="auth-tab" type="button" data-auth-mode="signup">Sign Up</button>
          </div>

          <form id="authForm" data-mode="login">
            <div class="field hidden" id="fullNameField">
              <label for="authName">Full name</label>
              <input id="authName" name="name" type="text" placeholder="Your full name">
            </div>
            <div class="field">
              <label for="authEmail">Email</label>
              <input id="authEmail" name="email" type="email" placeholder="name@example.com" required>
            </div>
            <div class="field">
              <label for="authPassword">Password</label>
              <div class="password-control">
                <input id="authPassword" name="password" type="password" placeholder="Your password" required>
                <button class="password-toggle" type="button" data-password-toggle="authPassword" aria-label="Show password" aria-pressed="false">&#128065;</button>
              </div>
              <small class="password-hint">Use at least 6 characters.</small>
            </div>
            <button class="forgot-password" type="button" data-forgot-password>Forgot password?</button>
            <p class="auth-message" role="status" aria-live="polite"></p>
            <button type="submit" class="btn auth-submit">Login</button>
          </form>

          <div class="divider"><span>or continue with</span></div>
          <div class="social-login">
            <button type="button" class="social-btn google" data-provider="google"><span class="social-mark fab fa-google" aria-hidden="true"></span><span>Google</span></button>
          </div>
        </div>
      </div>
    `;

    document.body.insertAdjacentHTML('beforeend', modalMarkup);
  }

  function setAuthMode(mode) {
    const form = document.getElementById('authForm');
    const fullNameField = document.getElementById('fullNameField');
    const submitButton = form?.querySelector('.auth-submit');
    const title = document.querySelector('.auth-title');
    const subtitle = document.querySelector('.auth-subtitle');
    const tabs = document.querySelectorAll('.auth-tab');

    if (!form) return;

    form.dataset.mode = mode;
    fullNameField.classList.toggle('hidden', mode !== 'signup');
    const passwordField = form.querySelector('#authPassword')?.closest('.field');
    const forgotLink = form.querySelector('[data-forgot-password]');
    const isForgot = mode === 'forgot';
    const isReset = mode === 'reset';
    fullNameField.classList.toggle('hidden', mode !== 'signup');
    passwordField?.classList.toggle('hidden', isForgot);
    forgotLink?.classList.toggle('hidden', mode !== 'login');
    const emailInput = form.querySelector('#authEmail');
    const passwordInput = form.querySelector('#authPassword');
    emailInput.closest('.field').classList.toggle('hidden', isReset);
    emailInput.required = !isReset;
    passwordInput.required = !isForgot;
    submitButton.textContent = mode === 'signup' ? 'Create account' : isForgot ? 'Send reset link' : isReset ? 'Save new password' : 'Login';
    title.textContent = mode === 'signup' ? 'Create your account' : isForgot ? 'Reset your password' : isReset ? 'Choose a new password' : 'Welcome back';
    subtitle.textContent = mode === 'signup'
      ? 'Join the Mayor Ride Co. community and get ready for your next ride.'
      : isForgot
        ? 'Enter your email and we will send instructions to reset your password.'
        : isReset
          ? 'Choose a new password for your account.'
          : 'Sign in to manage your account and keep your next ride moving.';

    tabs.forEach((tab) => {
      tab.classList.toggle('active', tab.dataset.authMode === mode);
    });
  }

  function openAuthModal(mode = 'login') {
    buildAuthModal();
    setAuthMode(mode);
    const modal = document.getElementById('authModal');
    if (modal) modal.classList.remove('hidden');
  }

  function closeAuthModal() {
    const modal = document.getElementById('authModal');
    if (modal) modal.classList.add('hidden');
  }

  // Store a one-time welcome message while moving the authenticated user to the homepage.
  function finishLogin(user) {
    sessionStorage.setItem('mrco_welcome_message', `Welcome to Mayor Ride Co., ${user.name}! You are now signed in.`);
    closeAuthModal();
    updateAuthUI();

    if (window.location.pathname.split('/').pop() !== 'index.html') {
      window.location.href = 'index.html';
      return;
    }

    showWelcomeMessage();
  }

  function showWelcomeMessage() {
    const message = sessionStorage.getItem('mrco_welcome_message');
    if (!message) return;

    sessionStorage.removeItem('mrco_welcome_message');
    document.querySelector('.welcome-toast')?.remove();
    document.body.insertAdjacentHTML('beforeend', `<div class="welcome-toast" role="status">${message}</div>`);
    window.setTimeout(() => document.querySelector('.welcome-toast')?.remove(), 6000);
  }

  async function handleSubmit(event) {
    event.preventDefault();
    const form = event.target;
    const mode = form.dataset.mode;
    const name = document.getElementById('authName')?.value.trim() || '';
    const email = document.getElementById('authEmail').value.trim();
    const password = document.getElementById('authPassword').value;
    const message = form.querySelector('.auth-message');
    const submitButton = form.querySelector('.auth-submit');
    let finalMode = mode;

    message.textContent = '';
    message.className = 'auth-message';
    submitButton.disabled = true;
    submitButton.textContent = mode === 'signup' ? 'Creating account...' : mode === 'forgot' ? 'Sending...' : mode === 'reset' ? 'Saving...' : 'Signing in...';

    try {
      const result = mode === 'signup'
        ? await registerUser({ name, email, password, provider: 'email' })
        : mode === 'forgot'
          ? await requestPasswordReset(email)
          : mode === 'reset'
            ? await updatePassword({ email: sessionStorage.getItem('mrco_reset_email') || email, password })
            : await loginUser({ email, password });

      if (!result.success) {
        message.textContent = result.message;
        message.classList.add('error');
        return;
      }

      if (mode === 'forgot') {
        if (result.localReset) {
          sessionStorage.setItem('mrco_reset_email', email);
          message.textContent = 'Account found. Choose a new password below.';
          message.classList.add('success');
          setAuthMode('reset');
        } else {
          message.textContent = 'Check your email for a password reset link.';
          message.classList.add('success');
        }
        return;
      }

      if (mode === 'reset') {
        sessionStorage.removeItem('mrco_reset_email');
        window.location.hash = '';
        message.textContent = 'Password updated. You can now log in.';
        message.classList.add('success');
        setAuthMode('login');
        return;
      }

      if (result.requiresConfirmation) {
        message.textContent = 'Account created. Confirm your email if required, then log in below.';
        message.classList.add('success');
        document.getElementById('authEmail').value = email;
        document.getElementById('authPassword').value = '';
        form.reset();
        document.getElementById('authEmail').value = email;
        setAuthMode('login');
        finalMode = 'login';
        document.getElementById('authEmail').focus();
        return;
      }

      finishLogin(result.user);
      form.reset();
    } catch (error) {
      message.textContent = 'We could not complete that request. Please try again.';
      message.classList.add('error');
    } finally {
      submitButton.disabled = false;
      setAuthMode(finalMode);
    }
  }

  async function handleSocial(provider) {
    const buttons = document.querySelectorAll('[data-provider]');
    const message = document.querySelector('.auth-message');
    buttons.forEach((button) => {
      button.disabled = true;
    });

    const result = await socialLogin(provider);
    if (result.success) {
      if (!result.redirecting) {
        finishLogin(result.user);
      }
    } else {
      if (message) {
        message.textContent = result.message || 'Unable to continue with social login.';
        message.className = 'auth-message error';
      }
    }

    buttons.forEach((button) => {
      button.disabled = false;
    });
  }

  function bindEvents() {
    document.addEventListener('click', (event) => {
      const authTrigger = event.target.closest('[data-auth]');
      if (authTrigger) {
        const mode = authTrigger.dataset.auth === 'signup' ? 'signup' : 'login';
        openAuthModal(mode);
        return;
      }

      if (event.target.closest('[data-close-auth]')) {
        closeAuthModal();
        return;
      }

      if (event.target.closest('[data-auth-mode]')) {
        setAuthMode(event.target.closest('[data-auth-mode]').dataset.authMode);
        return;
      }

      if (event.target.closest('[data-forgot-password]')) {
        setAuthMode('forgot');
        return;
      }

      const passwordToggle = event.target.closest('[data-password-toggle]');
      if (passwordToggle) {
        const input = document.getElementById(passwordToggle.dataset.passwordToggle);
        if (!input) return;
        const showing = input.type === 'text';
        input.type = showing ? 'password' : 'text';
        passwordToggle.setAttribute('aria-label', showing ? 'Show password' : 'Hide password');
        passwordToggle.setAttribute('aria-pressed', String(!showing));
      }

      if (event.target.closest('[data-provider]')) {
        handleSocial(event.target.closest('[data-provider]').dataset.provider);
        return;
      }

      if (event.target.closest('[data-logout]')) {
        clearCurrentUser();
        updateAuthUI();
      }
    });

    document.addEventListener('submit', (event) => {
      if (event.target && event.target.id === 'authForm') {
        handleSubmit(event);
      }
    });
  }

  document.addEventListener('DOMContentLoaded', () => {
    ensureDatabase();
    buildAuthModal();
    bindEvents();
    updateAuthUI();
    showWelcomeMessage();
    if (window.location.hash.includes('type=recovery')) {
      openAuthModal('reset');
    }
  });
})();
