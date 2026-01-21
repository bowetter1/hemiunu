document.addEventListener('DOMContentLoaded', () => {
    const todoForm = document.getElementById('todo-form');
    const todoInput = document.getElementById('todo-input');
    const todoList = document.getElementById('todo-list');

    // Fetch todos on load
    fetchTodos();

    // Add todo
    todoForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const title = todoInput.value.trim();
        if (title) {
            await addTodo(title);
            todoInput.value = '';
        }
    });

    async function fetchTodos() {
        try {
            const response = await fetch('/todos');
            const todos = await response.json();
            renderTodos(todos);
        } catch (error) {
            console.error('Error fetching todos:', error);
        }
    }

    async function addTodo(title) {
        try {
            const response = await fetch('/todos', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ title }),
            });
            if (response.ok) {
                await fetchTodos();
            }
        } catch (error) {
            console.error('Error adding todo:', error);
        }
    }

    async function toggleTodo(id) {
        try {
            const response = await fetch(`/todos/${id}`, {
                method: 'PUT',
            });
            if (response.ok) {
                await fetchTodos();
            }
        } catch (error) {
            console.error('Error toggling todo:', error);
        }
    }

    async function deleteTodo(id) {
        try {
            const response = await fetch(`/todos/${id}`, {
                method: 'DELETE',
            });
            if (response.ok) {
                await fetchTodos();
            }
        } catch (error) {
            console.error('Error deleting todo:', error);
        }
    }

    function renderTodos(todos) {
        todoList.innerHTML = '';
        todos.forEach(todo => {
            const li = document.createElement('li');
            li.className = 'todo-item';
            
            const content = document.createElement('div');
            content.className = 'todo-content';
            content.onclick = () => toggleTodo(todo.id);

            const checkbox = document.createElement('input');
            checkbox.type = 'checkbox';
            checkbox.checked = todo.completed;
            checkbox.onclick = (e) => {
                e.stopPropagation();
                toggleTodo(todo.id);
            };

            const span = document.createElement('span');
            span.className = `todo-text ${todo.completed ? 'completed' : ''}`;
            span.textContent = todo.title;

            content.appendChild(checkbox);
            content.appendChild(span);

            const deleteBtn = document.createElement('button');
            deleteBtn.className = 'btn-delete';
            deleteBtn.textContent = 'Delete';
            deleteBtn.onclick = () => deleteTodo(todo.id);

            li.appendChild(content);
            li.appendChild(deleteBtn);
            todoList.appendChild(li);
        });
    }
});
