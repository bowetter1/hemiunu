# test_api.py - Tests for todo API endpoints
import pytest


class TestGetTodos:
    """Tests for GET /todos endpoint."""

    @pytest.mark.asyncio
    async def test_get_todos_empty_list(self, client, test_db):
        """GET /todos returns empty list when no todos exist."""
        response = await client.get("/todos")
        assert response.status_code == 200
        assert response.json() == []

    @pytest.mark.asyncio
    async def test_get_todos_with_items(self, client, test_db):
        """GET /todos returns all todos when items exist."""
        # Create some todos first
        await client.post("/todos", json={"title": "First task"})
        await client.post("/todos", json={"title": "Second task"})

        response = await client.get("/todos")
        assert response.status_code == 200

        todos = response.json()
        assert len(todos) == 2
        assert todos[0]["title"] == "First task"
        assert todos[0]["completed"] == False
        assert todos[1]["title"] == "Second task"
        assert todos[1]["completed"] == False


class TestPostTodos:
    """Tests for POST /todos endpoint."""

    @pytest.mark.asyncio
    async def test_create_todo_success(self, client, test_db):
        """POST /todos creates a new todo and returns 201."""
        response = await client.post("/todos", json={"title": "Buy groceries"})

        assert response.status_code == 201
        data = response.json()
        assert data["id"] == 1
        assert data["title"] == "Buy groceries"
        assert data["completed"] == False

    @pytest.mark.asyncio
    async def test_create_todo_appears_in_list(self, client, test_db):
        """Created todo appears in GET /todos response."""
        await client.post("/todos", json={"title": "New task"})

        response = await client.get("/todos")
        todos = response.json()

        assert len(todos) == 1
        assert todos[0]["title"] == "New task"

    @pytest.mark.asyncio
    async def test_create_multiple_todos(self, client, test_db):
        """Multiple todos get unique IDs."""
        resp1 = await client.post("/todos", json={"title": "Task 1"})
        resp2 = await client.post("/todos", json={"title": "Task 2"})
        resp3 = await client.post("/todos", json={"title": "Task 3"})

        assert resp1.json()["id"] == 1
        assert resp2.json()["id"] == 2
        assert resp3.json()["id"] == 3

    @pytest.mark.asyncio
    async def test_create_todo_empty_title_fails(self, client, test_db):
        """POST /todos with empty title returns 400."""
        response = await client.post("/todos", json={"title": ""})
        assert response.status_code == 400

    @pytest.mark.asyncio
    async def test_create_todo_whitespace_title_fails(self, client, test_db):
        """POST /todos with whitespace-only title returns 400."""
        response = await client.post("/todos", json={"title": "   "})
        assert response.status_code == 400


class TestPutTodos:
    """Tests for PUT /todos/{id} endpoint."""

    @pytest.mark.asyncio
    async def test_toggle_complete_success(self, client, test_db):
        """PUT /todos/{id} toggles completed status from false to true."""
        # Create a todo
        create_resp = await client.post("/todos", json={"title": "Test todo"})
        todo_id = create_resp.json()["id"]

        # Toggle to completed
        response = await client.put(f"/todos/{todo_id}")

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == todo_id
        assert data["completed"] == True

    @pytest.mark.asyncio
    async def test_toggle_complete_twice(self, client, test_db):
        """PUT /todos/{id} toggles back to incomplete."""
        # Create a todo
        create_resp = await client.post("/todos", json={"title": "Test todo"})
        todo_id = create_resp.json()["id"]

        # Toggle to completed
        await client.put(f"/todos/{todo_id}")

        # Toggle back to incomplete
        response = await client.put(f"/todos/{todo_id}")

        assert response.status_code == 200
        assert response.json()["completed"] == False

    @pytest.mark.asyncio
    async def test_toggle_nonexistent_todo_returns_404(self, client, test_db):
        """PUT /todos/{id} returns 404 for non-existent todo."""
        response = await client.put("/todos/999")

        assert response.status_code == 404
        assert response.json()["detail"] == "Todo not found"


class TestDeleteTodos:
    """Tests for DELETE /todos/{id} endpoint."""

    @pytest.mark.asyncio
    async def test_delete_todo_success(self, client, test_db):
        """DELETE /todos/{id} removes the todo."""
        # Create a todo
        create_resp = await client.post("/todos", json={"title": "To delete"})
        todo_id = create_resp.json()["id"]

        # Delete it
        response = await client.delete(f"/todos/{todo_id}")

        assert response.status_code == 200
        assert response.json()["message"] == "Todo deleted"

    @pytest.mark.asyncio
    async def test_deleted_todo_not_in_list(self, client, test_db):
        """Deleted todo no longer appears in GET /todos."""
        # Create a todo
        create_resp = await client.post("/todos", json={"title": "To delete"})
        todo_id = create_resp.json()["id"]

        # Delete it
        await client.delete(f"/todos/{todo_id}")

        # Verify it's gone
        response = await client.get("/todos")
        assert response.json() == []

    @pytest.mark.asyncio
    async def test_delete_nonexistent_todo_returns_404(self, client, test_db):
        """DELETE /todos/{id} returns 404 for non-existent todo."""
        response = await client.delete("/todos/999")

        assert response.status_code == 404
        assert response.json()["detail"] == "Todo not found"

    @pytest.mark.asyncio
    async def test_delete_already_deleted_todo_returns_404(self, client, test_db):
        """Deleting a todo twice returns 404 on second attempt."""
        # Create and delete a todo
        create_resp = await client.post("/todos", json={"title": "To delete"})
        todo_id = create_resp.json()["id"]
        await client.delete(f"/todos/{todo_id}")

        # Try to delete again
        response = await client.delete(f"/todos/{todo_id}")
        assert response.status_code == 404


class TestTodoResponseFormat:
    """Tests for todo response format matching API contract."""

    @pytest.mark.asyncio
    async def test_todo_response_has_required_fields(self, client, test_db):
        """Todo response contains id, title, and completed fields."""
        response = await client.post("/todos", json={"title": "Test"})
        data = response.json()

        assert "id" in data
        assert "title" in data
        assert "completed" in data

    @pytest.mark.asyncio
    async def test_completed_is_boolean(self, client, test_db):
        """Completed field is a boolean, not an integer."""
        response = await client.post("/todos", json={"title": "Test"})
        data = response.json()

        assert isinstance(data["completed"], bool)
        assert data["completed"] == False  # Not 0

    @pytest.mark.asyncio
    async def test_id_is_integer(self, client, test_db):
        """ID field is an integer."""
        response = await client.post("/todos", json={"title": "Test"})
        data = response.json()

        assert isinstance(data["id"], int)
