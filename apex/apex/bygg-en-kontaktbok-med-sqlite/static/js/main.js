// Contact Book - Frontend JavaScript
// API Contract from PLAN.md:
// GET /contacts - list all contacts (optional: ?q=searchterm)
// POST /contacts - create contact {name, phone, email, notes}
// GET /contacts/{id} - get single contact
// PUT /contacts/{id} - update contact
// DELETE /contacts/{id} - delete contact

// DOM Elements
const contactList = document.getElementById('contactList');
const emptyState = document.getElementById('emptyState');
const loadingState = document.getElementById('loadingState');
const searchInput = document.getElementById('searchInput');

// Modal elements
const contactModal = document.getElementById('contactModal');
const modalTitle = document.getElementById('modalTitle');
const contactForm = document.getElementById('contactForm');
const contactIdInput = document.getElementById('contactId');
const nameInput = document.getElementById('nameInput');
const phoneInput = document.getElementById('phoneInput');
const emailInput = document.getElementById('emailInput');
const notesInput = document.getElementById('notesInput');
const nameError = document.getElementById('nameError');
const emailError = document.getElementById('emailError');
const saveBtn = document.getElementById('saveBtn');

// Delete modal elements
const deleteModal = document.getElementById('deleteModal');
const deleteContactNameSpan = document.getElementById('deleteContactName');
const confirmDeleteBtn = document.getElementById('confirmDeleteBtn');

// Toast container
const toastContainer = document.getElementById('toastContainer');

// State
let contacts = [];
let deleteContactId = null;
let searchTimeout = null;

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    loadContacts();
    setupEventListeners();
});

// Event Listeners
function setupEventListeners() {
    // Add contact button
    document.getElementById('addContactBtn').addEventListener('click', openAddModal);

    // Empty state CTA button
    const emptyAddBtn = document.getElementById('emptyAddBtn');
    if (emptyAddBtn) {
        emptyAddBtn.addEventListener('click', openAddModal);
    }

    // Close modal buttons
    document.getElementById('closeModalBtn').addEventListener('click', closeModal);
    document.getElementById('cancelBtn').addEventListener('click', closeModal);

    // Close delete modal buttons
    document.getElementById('closeDeleteModalBtn').addEventListener('click', closeDeleteModal);
    document.getElementById('cancelDeleteBtn').addEventListener('click', closeDeleteModal);

    // Form submission
    contactForm.addEventListener('submit', handleFormSubmit);

    // Delete confirmation
    confirmDeleteBtn.addEventListener('click', handleDelete);

    // Search
    searchInput.addEventListener('input', handleSearch);

    // Close modals on overlay click
    contactModal.addEventListener('click', (e) => {
        if (e.target === contactModal) closeModal();
    });
    deleteModal.addEventListener('click', (e) => {
        if (e.target === deleteModal) closeDeleteModal();
    });

    // Close modals on Escape key
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            closeModal();
            closeDeleteModal();
        }
    });
}

// API Functions

async function loadContacts(searchQuery = '') {
    showLoading(true);

    try {
        let url = '/contacts';
        if (searchQuery) {
            url += '?q=' + encodeURIComponent(searchQuery);
        }

        const response = await fetch(url);
        if (!response.ok) {
            throw new Error('Failed to load contacts');
        }

        contacts = await response.json();
        renderContacts();
    } catch (error) {
        console.error('Error loading contacts:', error);
        showToast('Kunde inte ladda kontakter', 'error');
    } finally {
        showLoading(false);
    }
}

async function createContact(contactData) {
    const response = await fetch('/contacts', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(contactData),
    });

    if (!response.ok) {
        const error = await response.json();
        throw new Error(error.detail || 'Failed to create contact');
    }

    return response.json();
}

async function updateContact(id, contactData) {
    const response = await fetch(`/contacts/${id}`, {
        method: 'PUT',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(contactData),
    });

    if (!response.ok) {
        const error = await response.json();
        throw new Error(error.detail || 'Failed to update contact');
    }

    return response.json();
}

async function deleteContact(id) {
    const response = await fetch(`/contacts/${id}`, {
        method: 'DELETE',
    });

    if (!response.ok) {
        const error = await response.json();
        throw new Error(error.detail || 'Failed to delete contact');
    }

    return response.json();
}

// UI Functions

function renderContacts() {
    if (contacts.length === 0) {
        contactList.innerHTML = '';
        emptyState.style.display = 'block';
        return;
    }

    emptyState.style.display = 'none';
    contactList.innerHTML = contacts.map(contact => createContactHTML(contact)).join('');

    // Add event listeners to edit/delete buttons
    contactList.querySelectorAll('.edit-btn').forEach(btn => {
        btn.addEventListener('click', () => openEditModal(btn.dataset.id));
    });

    contactList.querySelectorAll('.delete-btn').forEach(btn => {
        btn.addEventListener('click', () => openDeleteModal(btn.dataset.id));
    });
}

function createContactHTML(contact) {
    const initials = getInitials(contact.name);
    const details = [];

    if (contact.email) {
        details.push(`
            <span class="contact-detail">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"></path>
                    <polyline points="22,6 12,13 2,6"></polyline>
                </svg>
                ${escapeHtml(contact.email)}
            </span>
        `);
    }

    if (contact.phone) {
        details.push(`
            <span class="contact-detail">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"></path>
                </svg>
                ${escapeHtml(contact.phone)}
            </span>
        `);
    }

    return `
        <div class="contact-item" data-id="${contact.id}">
            <div class="avatar">${initials}</div>
            <div class="contact-info">
                <div class="contact-name">${escapeHtml(contact.name)}</div>
                ${details.length > 0 ? `<div class="contact-details">${details.join('')}</div>` : ''}
            </div>
            <div class="contact-actions">
                <button class="btn-icon edit-btn" data-id="${contact.id}" aria-label="Redigera">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M17 3a2.828 2.828 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"></path>
                    </svg>
                </button>
                <button class="btn-icon btn-danger-icon delete-btn" data-id="${contact.id}" aria-label="Ta bort">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <polyline points="3 6 5 6 21 6"></polyline>
                        <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
                        <line x1="10" y1="11" x2="10" y2="17"></line>
                        <line x1="14" y1="11" x2="14" y2="17"></line>
                    </svg>
                </button>
            </div>
        </div>
    `;
}

function getInitials(name) {
    if (!name) return '?';
    const parts = name.trim().split(/\s+/);
    if (parts.length === 1) {
        return parts[0].substring(0, 2).toUpperCase();
    }
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function showLoading(show) {
    loadingState.style.display = show ? 'block' : 'none';
    if (show) {
        contactList.innerHTML = '';
        emptyState.style.display = 'none';
    }
}

// Modal Functions

function openAddModal() {
    modalTitle.textContent = 'Lägg till kontakt';
    saveBtn.textContent = 'Spara';
    contactForm.reset();
    contactIdInput.value = '';
    clearErrors();
    contactModal.style.display = 'flex';
    nameInput.focus();
}

function openEditModal(id) {
    const contact = contacts.find(c => c.id === parseInt(id));
    if (!contact) return;

    modalTitle.textContent = 'Redigera kontakt';
    saveBtn.textContent = 'Spara';
    contactIdInput.value = contact.id;
    nameInput.value = contact.name || '';
    phoneInput.value = contact.phone || '';
    emailInput.value = contact.email || '';
    notesInput.value = contact.notes || '';
    clearErrors();
    contactModal.style.display = 'flex';
    nameInput.focus();
}

function closeModal() {
    contactModal.style.display = 'none';
    contactForm.reset();
    clearErrors();
}

function openDeleteModal(id) {
    deleteContactId = parseInt(id);
    const contact = contacts.find(c => c.id === deleteContactId);
    if (contact && deleteContactNameSpan) {
        deleteContactNameSpan.textContent = contact.name;
    }
    deleteModal.style.display = 'flex';
}

function closeDeleteModal() {
    deleteModal.style.display = 'none';
    deleteContactId = null;
}

// Form Handling

async function handleFormSubmit(e) {
    e.preventDefault();
    clearErrors();

    const name = nameInput.value.trim();
    const phone = phoneInput.value.trim();
    const email = emailInput.value.trim();
    const notes = notesInput.value.trim();

    // Validation
    let hasError = false;

    if (!name) {
        showFieldError(nameError, nameInput, 'Namn är obligatoriskt');
        hasError = true;
    }

    if (email && !isValidEmail(email)) {
        showFieldError(emailError, emailInput, 'Ogiltig e-postadress');
        hasError = true;
    }

    if (hasError) return;

    const contactData = {
        name,
        phone: phone || null,
        email: email || null,
        notes: notes || null,
    };

    saveBtn.disabled = true;
    saveBtn.textContent = 'Sparar...';

    try {
        const id = contactIdInput.value;
        if (id) {
            await updateContact(id, contactData);
            showToast('Kontakt uppdaterad', 'success');
        } else {
            await createContact(contactData);
            showToast('Kontakt skapad', 'success');
        }

        closeModal();
        loadContacts(searchInput.value.trim());
    } catch (error) {
        console.error('Error saving contact:', error);
        showToast(error.message || 'Kunde inte spara kontakt', 'error');
    } finally {
        saveBtn.disabled = false;
        saveBtn.textContent = 'Spara';
    }
}

async function handleDelete() {
    if (!deleteContactId) return;

    confirmDeleteBtn.disabled = true;
    confirmDeleteBtn.textContent = 'Tar bort...';

    try {
        await deleteContact(deleteContactId);

        // Animate the contact item before removing
        const contactItem = contactList.querySelector(`.contact-item[data-id="${deleteContactId}"]`);
        if (contactItem) {
            contactItem.classList.add('contact-deleting');
            await new Promise(resolve => {
                contactItem.addEventListener('animationend', resolve, { once: true });
            });
        }

        showToast('Kontakten har tagits bort', 'success');
        closeDeleteModal();
        loadContacts(searchInput.value.trim());
    } catch (error) {
        console.error('Error deleting contact:', error);
        showToast(error.message || 'Kunde inte ta bort kontakt', 'error');
    } finally {
        confirmDeleteBtn.disabled = false;
        confirmDeleteBtn.textContent = 'Ta bort';
    }
}

function handleSearch(e) {
    const query = e.target.value.trim();

    // Debounce search
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
        loadContacts(query);
    }, 300);
}

// Validation

function isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function showFieldError(errorElement, inputElement, message) {
    const errorText = errorElement.querySelector('.error-text');
    if (errorText) {
        errorText.textContent = message;
    }
    errorElement.classList.add('visible');
    inputElement.classList.add('error');
}

function clearFieldError(errorElement, inputElement) {
    const errorText = errorElement.querySelector('.error-text');
    if (errorText) {
        errorText.textContent = '';
    }
    errorElement.classList.remove('visible');
    inputElement.classList.remove('error');
}

function clearErrors() {
    clearFieldError(nameError, nameInput);
    clearFieldError(emailError, emailInput);
}

// Toast Notifications

function getToastIcon(type) {
    const icons = {
        success: `<svg class="toast-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
            <polyline points="22 4 12 14.01 9 11.01"></polyline>
        </svg>`,
        error: `<svg class="toast-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="12" r="10"></circle>
            <line x1="12" y1="8" x2="12" y2="12"></line>
            <line x1="12" y1="16" x2="12.01" y2="16"></line>
        </svg>`,
        warning: `<svg class="toast-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path>
            <line x1="12" y1="9" x2="12" y2="13"></line>
            <line x1="12" y1="17" x2="12.01" y2="17"></line>
        </svg>`
    };
    return icons[type] || icons.success;
}

function showToast(message, type = 'success') {
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;

    const icon = getToastIcon(type);
    const closeIcon = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <line x1="18" y1="6" x2="6" y2="18"></line>
        <line x1="6" y1="6" x2="18" y2="18"></line>
    </svg>`;

    toast.innerHTML = `
        ${icon}
        <span class="toast-message">${escapeHtml(message)}</span>
        <button class="toast-close" aria-label="Stäng">${closeIcon}</button>
    `;

    // Close button handler
    const closeBtn = toast.querySelector('.toast-close');
    closeBtn.addEventListener('click', () => removeToast(toast));

    toastContainer.appendChild(toast);

    // Auto-dismiss: success 3s, warning 5s, error never
    if (type === 'success') {
        setTimeout(() => removeToast(toast), 3000);
    } else if (type === 'warning') {
        setTimeout(() => removeToast(toast), 5000);
    }
    // Error toasts require manual close - no auto-dismiss
}

function removeToast(toast) {
    if (!toast || !toast.parentNode) return;

    toast.classList.add('hiding');
    toast.addEventListener('animationend', () => {
        if (toast.parentNode) {
            toast.parentNode.removeChild(toast);
        }
    });
}
