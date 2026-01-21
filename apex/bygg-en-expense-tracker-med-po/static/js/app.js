
// Function to show error message for a specific field
function showError(fieldId, message) {
    const field = document.getElementById(fieldId);
    field.classList.add('input-error');
    
    // Create error message element
    const errorElement = document.createElement('div');
    errorElement.className = 'error-message';
    errorElement.textContent = message;
    errorElement.id = `${fieldId}-error`;
    
    // Insert error message after the field
    field.parentNode.insertBefore(errorElement, field.nextSibling);
}

// Function to clear all error messages
function clearErrors() {
    // Remove all error message elements
    const errorElements = document.querySelectorAll('.error-message');
    errorElements.forEach(element => element.remove());
    
    // Remove error styling from inputs
    const errorInputs = document.querySelectorAll('.input-error');
    errorInputs.forEach(input => input.classList.remove('input-error'));
}

// Function to display API validation errors
function displayApiErrors(errorData) {
    if (errorData.detail && Array.isArray(errorData.detail)) {
        errorData.detail.forEach(error => {
            if (error.loc && error.loc.length >= 2) {
                const field = error.loc[1]; // The field name is at index 1
                let fieldId = field;
                
                // Map API field names to form field IDs if needed
                if (field === 'amount') fieldId = 'amount';
                else if (field === 'description') fieldId = 'description';
                else if (field === 'category') fieldId = 'category';
                else if (field === 'date') fieldId = 'date';
                
                showError(fieldId, error.msg);
            }
        });
    } else {
        showError('form', 'An error occurred while saving the expense. Please try again.');
    }
}

// Function to show success message
function showSuccess(message) {
    // Create success notification
    const toast = document.createElement('div');
    toast.className = 'toast-success';
    toast.textContent = message;

    // Add to DOM
    document.body.appendChild(toast);

    // Remove after 3 seconds
    setTimeout(() => {
        toast.remove();
    }, 3000);
}

// Function to sanitize HTML by escaping dangerous characters
function sanitizeHtml(str) {
    if (typeof str !== 'string') {
        return str;
    }
    return str
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#x27;');
}

// Function to format date as "Jan 21, 2026"
function formatDate(dateString) {
    const options = { year: 'numeric', month: 'short', day: 'numeric' };
    const date = new Date(dateString);
    return date.toLocaleDateString(undefined, options);
}

// Function to format amount with currency and commas
function formatAmount(amount) {
    // Convert to number and format with 2 decimal places
    const num = parseFloat(amount);
    return num.toLocaleString(undefined, {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
    });
}

// Function to get category icon
function getCategoryIcon(category) {
    const icons = {
        'Food': '🍔',
        'Transport': '🚗',
        'Entertainment': '🎬',
        'Bills': '📄',
        'Shopping': '🛒',
        'Other': '📦'
    };
    return icons[category] || '📦';
}

// Function to get category badge class
function getCategoryBadgeClass(category) {
    const classes = {
        'Food': 'food',
        'Transport': 'transport',
        'Entertainment': 'entertainment',
        'Bills': 'bills',
        'Shopping': 'shopping',
        'Other': 'other'
    };
    return classes[category] || 'other';
}

// Function to display expenses in the table
function displayExpenses(expenses) {
    const expenseList = document.getElementById('expense-list');
    const emptyState = document.getElementById('empty-state');
    const loadingState = document.getElementById('loading-state');
    const totalAmountEl = document.querySelector('.total-amount');

    // Clear current list
    expenseList.innerHTML = '';

    if (expenses.length === 0) {
        // Show empty state
        emptyState.style.display = 'block';
        expenseList.style.display = 'none';

        // Set total to 0
        totalAmountEl.textContent = 'kr 0.00';
    } else {
        // Hide empty state
        emptyState.style.display = 'none';
        expenseList.style.display = 'table-row-group';

        // Calculate total
        let total = 0;

        // Add each expense to the table
        expenses.forEach(expense => {
            const row = document.createElement('tr');
            row.setAttribute('data-id', expense.id);

            // Format the amount and add to total
            const formattedAmount = formatAmount(expense.amount);
            total += parseFloat(expense.amount);

            // Safely set content using textContent to prevent XSS
            const dateCell = document.createElement('td');
            dateCell.className = 'expense-date';
            dateCell.setAttribute('data-label', 'Date');
            dateCell.textContent = formatDate(expense.date);

            const descriptionCell = document.createElement('td');
            descriptionCell.className = 'expense-description';
            descriptionCell.setAttribute('data-label', 'Description');
            descriptionCell.textContent = expense.description; // Safe: using textContent

            const categoryCell = document.createElement('td');
            categoryCell.className = 'expense-category';
            categoryCell.setAttribute('data-label', 'Category');

            // Create category badge element safely
            const categoryBadge = document.createElement('span');
            categoryBadge.className = `category-badge ${getCategoryBadgeClass(expense.category)}`;
            categoryBadge.innerHTML = `${getCategoryIcon(expense.category)} ${sanitizeHtml(expense.category)}`;
            categoryCell.appendChild(categoryBadge);

            const amountCell = document.createElement('td');
            amountCell.className = 'expense-amount';
            amountCell.setAttribute('data-label', 'Amount');
            amountCell.textContent = `kr ${formattedAmount}`; // Safe: using textContent

            const actionsCell = document.createElement('td');
            actionsCell.className = 'expense-actions';
            actionsCell.setAttribute('data-label', 'Actions');
            actionsCell.innerHTML = `<button class="btn-delete" data-id="${expense.id}" aria-label="Delete expense" title="Delete">🗑️</button>`;

            row.appendChild(dateCell);
            row.appendChild(descriptionCell);
            row.appendChild(categoryCell);
            row.appendChild(amountCell);
            row.appendChild(actionsCell);

            expenseList.appendChild(row);
        });

        // Update total amount
        totalAmountEl.textContent = `kr ${formatAmount(total.toFixed(2))}`;
    }

    // Hide loading state
    loadingState.style.display = 'none';
}

// Function to fetch expenses from the API
async function fetchExpenses() {
    const loadingState = document.getElementById('loading-state');
    const emptyState = document.getElementById('empty-state');

    // Show loading state
    loadingState.style.display = 'flex';
    emptyState.style.display = 'none';

    try {
        const response = await fetch('/expenses');

        if (response.ok) {
            const data = await response.json();
            displayExpenses(data.expenses);
        } else {
            console.error('Failed to fetch expenses:', response.status);
            loadingState.style.display = 'none';
            // Still hide loading and show empty state if there's an error
            document.getElementById('expense-list').innerHTML = '';
            emptyState.style.display = 'block';
        }
    } catch (error) {
        console.error('Error fetching expenses:', error);
        loadingState.style.display = 'none';
        // Still hide loading and show empty state if there's an error
        document.getElementById('expense-list').innerHTML = '';
        emptyState.style.display = 'block';
    }
}

// Refresh expenses after adding a new one
function refreshExpensesAfterAdd() {
    // Small delay to allow the backend to process the new expense
    setTimeout(fetchExpenses, 500);
}

// Function to delete an expense
async function deleteExpense(id, description) {
    // Sanitize description to prevent XSS in confirm dialog
    const sanitizedDescription = description ? description.replace(/[<>&"]/g, function(match) {
        switch(match) {
            case '<': return '&lt;';
            case '>': return '&gt;';
            case '&': return '&amp;';
            case '"': return '&quot;';
            default: return match;
        }
    }) : '';

    const message = sanitizedDescription
        ? `Delete "${sanitizedDescription}"?`
        : 'Delete this expense?';

    if (!confirm(message)) {
        return;
    }

    try {
        const response = await fetch(`/expenses/${id}`, {
            method: 'DELETE'
        });

        if (response.status === 204) {
            // Remove row from table with animation
            const row = document.querySelector(`tr[data-id="${id}"]`);
            if (row) {
                // Add animation class
                row.classList.add('expense-row-deleting');

                // Wait for animation to complete before removing
                setTimeout(() => {
                    row.remove();

                    // Check if table is now empty, show empty state if needed
                    checkEmptyState();

                    // Show success message
                    showSuccess('Expense deleted');

                    // Refresh the summary after deletion
                    refreshSummaryAfterDelete();
                }, 300);
            }
        } else if (response.status === 404) {
            alert('Expense not found. It may have been already deleted.');
            // Refresh the list and summary to sync with server
            fetchExpenses();
            loadSummary();
        } else {
            alert('Failed to delete expense. Please try again.');
        }
    } catch (error) {
        console.error('Error deleting expense:', error);
        alert('An error occurred while deleting the expense. Please try again.');
    }
}

// Check if expense list is empty and show/hide empty state
function checkEmptyState() {
    const expenseList = document.getElementById('expense-list');
    const emptyState = document.getElementById('empty-state');

    if (expenseList.children.length === 0) {
        emptyState.style.display = 'block';
        expenseList.style.display = 'none';
    } else {
        emptyState.style.display = 'none';
        expenseList.style.display = 'table-row-group';
    }
}

// Event delegation for delete buttons
document.getElementById('expense-list').addEventListener('click', function(e) {
    if (e.target.classList.contains('btn-delete') || e.target.closest('.btn-delete')) {
        const button = e.target.classList.contains('btn-delete') ? e.target : e.target.closest('.btn-delete');
        const id = parseInt(button.getAttribute('data-id'));
        const row = button.closest('tr');
        const descriptionCell = row.querySelector('.expense-description');
        const description = descriptionCell ? descriptionCell.textContent : '';

        deleteExpense(id, description);
    }
});

// Function to load summary data
async function loadSummary() {
    try {
        const response = await fetch('/expenses/summary');

        if (response.ok) {
            const data = await response.json();

            // Update total amount
            document.getElementById('total-amount-summary').textContent = `kr ${formatAmount(data.total)}`;

            // Update expense count
            const countText = data.count === 1 ? '1 expense' : `${data.count} expenses`;
            document.getElementById('expense-count').textContent = countText;

            // Render category breakdown
            renderCategoryBreakdown(data.by_category, data.total);
        } else {
            console.error('Failed to fetch summary:', response.status);
        }
    } catch (error) {
        console.error('Error fetching summary:', error);
    }
}

// Function to render category breakdown
function renderCategoryBreakdown(byCategory, total) {
    const categoryList = document.getElementById('category-list');
    const chartContainer = document.getElementById('category-chart');
    const summaryEmptyState = document.getElementById('summary-empty-state');

    // Clear current lists
    categoryList.innerHTML = '';
    chartContainer.innerHTML = '';

    // Category colors
    const colors = {
        'Food': '#F59E0B',
        'Transport': '#3B82F6',
        'Entertainment': '#8B5CF6',
        'Bills': '#EF4444',
        'Shopping': '#10B981',
        'Other': '#6B7280'
    };

    // Category icons
    const icons = {
        'Food': '🍔',
        'Transport': '🚗',
        'Entertainment': '🎬',
        'Bills': '📄',
        'Shopping': '🛒',
        'Other': '📦'
    };

    // Check if there are any categories
    const categories = Object.keys(byCategory);
    if (categories.length === 0) {
        // Show empty state
        summaryEmptyState.style.display = 'block';
        categoryList.style.display = 'none';
        chartContainer.style.display = 'none';
        return;
    }

    // Hide empty state
    summaryEmptyState.style.display = 'none';
    categoryList.style.display = 'block';
    chartContainer.style.display = 'block';

    // Calculate total for percentage calculation
    const totalNum = parseFloat(total) || 1; // Avoid division by zero

    // Sort categories by amount (highest first)
    const sortedCategories = categories.sort((a, b) => parseFloat(byCategory[b]) - parseFloat(byCategory[a]));

    // Create chart bars and list items
    sortedCategories.forEach(category => {
        const amount = byCategory[category];
        const amountNum = parseFloat(amount);
        const percent = Math.round((amountNum / totalNum) * 100);

        // Create chart bar
        const bar = document.createElement('div');
        bar.className = 'bar';
        bar.style.setProperty('--width', `${Math.max(percent, 5)}%`); // Minimum width so it's visible
        bar.style.setProperty('--color', colors[category] || '#6B7280');

        const labelSpan = document.createElement('span');
        labelSpan.className = 'bar-label';
        // Sanitize category name to prevent XSS
        labelSpan.innerHTML = `${icons[category] || '📦'} ${sanitizeHtml(category)}`;

        const valueSpan = document.createElement('span');
        valueSpan.className = 'bar-value';
        valueSpan.textContent = `kr ${formatAmount(amount)} (${percent}%)`; // Safe: using textContent

        bar.appendChild(labelSpan);
        bar.appendChild(valueSpan);
        chartContainer.appendChild(bar);

        // Create list item
        const listItem = document.createElement('li');
        listItem.className = 'category-item';

        // Get category badge class
        const categoryClass = getCategoryBadgeClass(category);
        const badgeSpan = document.createElement('span');
        badgeSpan.className = `category-badge ${categoryClass}`;
        // Sanitize category name to prevent XSS
        badgeSpan.innerHTML = `${icons[category]} ${sanitizeHtml(category)}`;

        const amountDiv = document.createElement('div');

        const amountSpan = document.createElement('span');
        amountSpan.className = 'category-amount';
        amountSpan.textContent = `kr ${formatAmount(amount)}`; // Safe: using textContent

        const percentSpan = document.createElement('span');
        percentSpan.className = 'category-percent';
        percentSpan.textContent = `${percent}%`; // Safe: using textContent

        amountDiv.appendChild(amountSpan);
        amountDiv.appendChild(percentSpan);

        listItem.appendChild(badgeSpan);
        listItem.appendChild(amountDiv);
        categoryList.appendChild(listItem);
    });
}

// Fetch expenses when the page loads
document.addEventListener('DOMContentLoaded', function() {
    // Set today's date as default value for the date input
    const today = new Date().toISOString().split('T')[0];
    const dateInput = document.getElementById('date');
    if (dateInput.value === '') {
        dateInput.value = today;
    }

    // Handle form submission
    const form = document.getElementById('expense-form');
    form.addEventListener('submit', async function(e) {
        e.preventDefault();

        // Get form values
        const amount = document.getElementById('amount').value;
        const description = document.getElementById('description').value;
        const category = document.getElementById('category').value;
        const date = document.getElementById('date').value;

        // Clear previous error messages
        clearErrors();

        // Validate form
        let isValid = true;
        if (!amount || parseFloat(amount) <= 0) {
            showError('amount', 'Please enter an amount greater than 0');
            isValid = false;
        }

        if (!category) {
            showError('category', 'Please select a category');
            isValid = false;
        }

        if (!isValid) {
            return;
        }

        // Disable submit button and show loading state
        const submitBtn = document.querySelector('.btn-submit');
        const originalText = submitBtn.textContent;
        submitBtn.disabled = true;
        submitBtn.classList.add('loading');
        submitBtn.textContent = '';

        try {
            // Send POST request to /expenses
            const response = await fetch('/expenses', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    amount: parseFloat(amount),
                    description: description,
                    category: category,
                    date: date
                })
            });

            if (response.ok) {
                // Success: show success message and reset form
                showSuccess('Expense added successfully!');
                form.reset();

                // Reset date to today after clearing
                document.getElementById('date').value = today;

                // Refresh the expense list and summary
                refreshExpensesAfterAdd();
                loadSummary(); // Refresh summary after adding expense
            } else {
                // Error: parse and display error message
                const errorData = await response.json();
                displayApiErrors(errorData);
            }
        } catch (error) {
            // Network error or other exception
            showError('form', 'An error occurred while saving the expense. Please try again.');
            console.error('Error submitting expense:', error);
        } finally {
            // Re-enable submit button and remove loading state
            submitBtn.disabled = false;
            submitBtn.classList.remove('loading');
            submitBtn.textContent = originalText;
        }
    });

    // Fetch expenses and summary when the page loads
    fetchExpenses();
    loadSummary();
});

// Refresh summary after deleting an expense
function refreshSummaryAfterDelete() {
    // Small delay to allow the backend to process the deletion
    setTimeout(loadSummary, 500);
}