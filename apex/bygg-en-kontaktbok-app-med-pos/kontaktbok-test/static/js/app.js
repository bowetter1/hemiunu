/**
 * Kontaktbok - Frontend JavaScript
 * Sprint 2: Add Contact Form
 * Sprint 3: Contact List View
 * Sprint 4: Search Contacts
 * Sprint 5: Delete Contact
 */

// Wait for DOM to be fully loaded
document.addEventListener('DOMContentLoaded', function() {
    // Load contacts on page load
    loadContacts();
    const form = document.getElementById('addContactForm');
    const nameInput = document.getElementById('name');
    const emailInput = document.getElementById('email');
    const phoneInput = document.getElementById('phone');

    // Sprint 4: Search functionality
    const searchInput = document.getElementById('contactSearch');
    const clearButton = document.getElementById('clearSearch');
    let searchDebounceTimer = null;

    // Email validation regex (matches backend)
    const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;

    /**
     * Validate name field (required)
     */
    function validateName() {
        const value = nameInput.value.trim();
        const errorSpan = nameInput.parentElement.querySelector('.error-message');

        if (!value) {
            nameInput.classList.add('input-invalid');
            nameInput.classList.remove('input-valid');
            nameInput.setAttribute('aria-invalid', 'true');
            errorSpan.textContent = 'Namn är obligatoriskt';
            errorSpan.classList.add('visible');
            return false;
        } else {
            nameInput.classList.remove('input-invalid');
            nameInput.classList.add('input-valid');
            nameInput.setAttribute('aria-invalid', 'false');
            errorSpan.textContent = '';
            errorSpan.classList.remove('visible');
            return true;
        }
    }

    /**
     * Validate email field (optional but must be valid format if provided)
     */
    function validateEmail() {
        const value = emailInput.value.trim();
        const errorSpan = emailInput.parentElement.querySelector('.error-message');

        // Email is optional, so empty is valid
        if (!value) {
            emailInput.classList.remove('input-invalid');
            emailInput.classList.remove('input-valid');
            emailInput.setAttribute('aria-invalid', 'false');
            errorSpan.textContent = '';
            errorSpan.classList.remove('visible');
            return true;
        }

        // If email is provided, validate format
        if (!emailRegex.test(value)) {
            emailInput.classList.add('input-invalid');
            emailInput.classList.remove('input-valid');
            emailInput.setAttribute('aria-invalid', 'true');
            errorSpan.textContent = 'Ogiltig e-postadress (exempel: namn@example.com)';
            errorSpan.classList.add('visible');
            return false;
        } else {
            emailInput.classList.remove('input-invalid');
            emailInput.classList.add('input-valid');
            emailInput.setAttribute('aria-invalid', 'false');
            errorSpan.textContent = '';
            errorSpan.classList.remove('visible');
            return true;
        }
    }

    /**
     * Validate on blur (when user leaves field)
     */
    nameInput.addEventListener('blur', validateName);
    emailInput.addEventListener('blur', validateEmail);

    /**
     * Real-time error removal (as soon as input becomes valid)
     */
    nameInput.addEventListener('input', function() {
        if (nameInput.classList.contains('input-invalid') && nameInput.value.trim()) {
            validateName();
        }
    });

    emailInput.addEventListener('input', function() {
        if (emailInput.classList.contains('input-invalid')) {
            validateEmail();
        }
    });

    /**
     * Show toast notification
     */
    function showToast(type, title, message) {
        const container = document.getElementById('toastContainer');

        const toast = document.createElement('div');
        toast.className = `toast toast-${type}`;

        const icon = type === 'success' ? '✓' : '✗';

        toast.innerHTML = `
            <div class="toast-icon">${icon}</div>
            <div class="toast-content">
                <div class="toast-title">${title}</div>
                <div class="toast-message">${message}</div>
            </div>
            <button class="toast-close" aria-label="Stäng">&times;</button>
            <div class="toast-progress"></div>
        `;

        container.appendChild(toast);

        // Close button handler
        const closeBtn = toast.querySelector('.toast-close');
        closeBtn.addEventListener('click', () => {
            toast.style.animation = 'slideOutRight 0.3s ease';
            setTimeout(() => toast.remove(), 300);
        });

        // Auto-dismiss after 4 seconds
        setTimeout(() => {
            if (toast.parentElement) {
                toast.style.animation = 'slideOutRight 0.3s ease';
                setTimeout(() => toast.remove(), 300);
            }
        }, 4000);

        // Keyboard dismiss (Esc)
        const escHandler = (e) => {
            if (e.key === 'Escape') {
                toast.style.animation = 'slideOutRight 0.3s ease';
                setTimeout(() => toast.remove(), 300);
                document.removeEventListener('keydown', escHandler);
            }
        };
        document.addEventListener('keydown', escHandler);
    }

    /**
     * Handle form submission
     */
    form.addEventListener('submit', async function(e) {
        e.preventDefault();

        // Validate all fields before submission
        const isNameValid = validateName();
        const isEmailValid = validateEmail();

        if (!isNameValid || !isEmailValid) {
            return;
        }

        // Get form values and trim whitespace
        const formData = {
            name: nameInput.value.trim(),
            email: emailInput.value.trim() || null,
            phone: phoneInput.value.trim() || null
        };

        // Remove null values (backend expects missing fields for optional data)
        const requestBody = {};
        if (formData.name) requestBody.name = formData.name;
        if (formData.email) requestBody.email = formData.email;
        if (formData.phone) requestBody.phone = formData.phone;

        // Update button to loading state
        const submitBtn = form.querySelector('.btn-submit');
        const originalText = submitBtn.textContent;
        submitBtn.disabled = true;
        submitBtn.innerHTML = '<span class="spinner"></span>Lägger till...';

        try {
            const response = await fetch('/contacts', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(requestBody)
            });

            const data = await response.json();

            if (response.ok) {
                // Success (201)
                showToast('success', 'Kontakt tillagd!', `${data.name} har sparats`);

                // Clear form
                form.reset();

                // Remove validation classes
                nameInput.classList.remove('input-valid', 'input-invalid');
                emailInput.classList.remove('input-valid', 'input-invalid');

                // Reset aria-invalid
                nameInput.setAttribute('aria-invalid', 'false');
                emailInput.setAttribute('aria-invalid', 'false');

                // Reload contacts to show the newly added contact
                loadContacts();

                // Focus back to name field
                nameInput.focus();
            } else if (response.status === 400) {
                // Bad request (name validation error)
                showToast('error', 'Valideringsfel', data.detail || 'Namn är obligatoriskt');
            } else if (response.status === 422) {
                // Validation error (email format)
                showToast('error', 'Valideringsfel', data.detail || 'Ogiltig e-postadress');
            } else {
                // Other errors
                showToast('error', 'Ett fel uppstod', 'Kunde inte lägga till kontakt. Försök igen.');
            }
        } catch (error) {
            // Network error
            console.error('Error:', error);
            showToast('error', 'Nätverksfel', 'Kunde inte ansluta till servern. Kontrollera din anslutning.');
        } finally {
            // Restore button
            submitBtn.disabled = false;
            submitBtn.textContent = originalText;
        }
    });

    /**
     * Sprint 3: Load contacts from the server
     * Sprint 4: Added optional query parameter for search
     */
    async function loadContacts(query = '') {
        const contactGrid = document.getElementById('contactGrid');
        const emptyState = document.getElementById('emptyState');
        const noResultsState = document.getElementById('noResultsState');
        const contactCount = document.getElementById('contactCount');
        const searchResultsStatus = document.getElementById('searchResultsStatus');

        try {
            // Build URL with optional query parameter
            let url = '/contacts';
            if (query) {
                url += `?q=${encodeURIComponent(query)}`;
            }

            const response = await fetch(url, {
                method: 'GET',
                headers: {
                    'Content-Type': 'application/json',
                }
            });

            if (!response.ok) {
                throw new Error('Failed to fetch contacts');
            }

            const contacts = await response.json();

            // Render the contact list with search state
            renderContactList(contacts, query);

            // Update screen reader announcement
            if (query) {
                if (contacts.length === 0) {
                    searchResultsStatus.textContent = `Inga kontakter hittades för "${query}"`;
                } else {
                    searchResultsStatus.textContent = `${contacts.length} kontakter hittades`;
                }
            } else {
                searchResultsStatus.textContent = '';
            }

        } catch (error) {
            console.error('Error loading contacts:', error);
            showToast('error', 'Ett fel uppstod', 'Kunde inte ladda kontakter. Försök igen.');
        }
    }

    /**
     * Sprint 3: Render contact list
     * Sprint 4: Updated to handle search query and no results state
     */
    function renderContactList(contacts, query = '') {
        const contactGrid = document.getElementById('contactGrid');
        const emptyState = document.getElementById('emptyState');
        const noResultsState = document.getElementById('noResultsState');
        const contactCount = document.getElementById('contactCount');

        // Update contact count
        contactCount.textContent = `(${contacts.length})`;

        // Show appropriate empty state
        if (contacts.length === 0) {
            contactGrid.style.display = 'none';

            // If search is active, show "no results" state
            if (query) {
                emptyState.style.display = 'none';
                noResultsState.style.display = 'flex';
            } else {
                // If no search, show regular empty state
                noResultsState.style.display = 'none';
                emptyState.style.display = 'flex';
            }
            return;
        }

        // Hide both empty states and show grid
        emptyState.style.display = 'none';
        noResultsState.style.display = 'none';
        contactGrid.style.display = 'grid';

        // Clear existing contacts
        contactGrid.innerHTML = '';

        // Render each contact as a card
        contacts.forEach((contact) => {
            const card = document.createElement('article');
            card.className = 'contact-card';
            card.setAttribute('role', 'article');

            const nameEl = document.createElement('h3');
            nameEl.className = 'contact-name';
            nameEl.textContent = contact.name;

            const emailEl = document.createElement('p');
            emailEl.className = 'contact-email';
            emailEl.textContent = contact.email || '';

            const phoneEl = document.createElement('p');
            phoneEl.className = 'contact-phone';
            phoneEl.textContent = contact.phone || '';

            card.appendChild(nameEl);
            card.appendChild(emailEl);
            card.appendChild(phoneEl);

            contactGrid.appendChild(card);
        });
    }

    /**
     * Sprint 4: Search contacts with debounce
     */
    function performSearch(query) {
        const trimmedQuery = query.trim();

        // Update clear button visibility
        if (trimmedQuery) {
            clearButton.style.display = 'flex';
        } else {
            clearButton.style.display = 'none';
        }

        // Fetch contacts with search query
        loadContacts(trimmedQuery);
    }

    /**
     * Sprint 4: Handle search input with debounce
     */
    searchInput.addEventListener('input', function(e) {
        const query = e.target.value;

        // Clear previous timer
        if (searchDebounceTimer) {
            clearTimeout(searchDebounceTimer);
        }

        // Debounce: wait 300ms after user stops typing
        searchDebounceTimer = setTimeout(() => {
            performSearch(query);
        }, 300);
    });

    /**
     * Sprint 4: Clear search button
     */
    clearButton.addEventListener('click', function() {
        searchInput.value = '';
        clearButton.style.display = 'none';
        loadContacts('');
        searchInput.focus();
    });

    /**
     * Sprint 4: Clear search on Esc key
     */
    searchInput.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
            searchInput.value = '';
            clearButton.style.display = 'none';
            loadContacts('');
        }
    });

    /**
     * Make loadContacts and renderContactList available globally
     * so we can update the list after adding a new contact
     */
    window.loadContacts = loadContacts;
    window.renderContactList = renderContactList;
});
