import React, { useState, useEffect } from 'react';
import {
  AppBar,
  Toolbar,
  Typography,
  Container,
  Card,
  CardContent,
  Grid,
  TextField,
  Button,
  List,
  ListItem,
  ListItemText,
  Box,
  Alert,
  CircularProgress,
  IconButton
} from '@mui/material';
import { Add as AddIcon, Assignment as AssignmentIcon, Delete as DeleteIcon, Edit as EditIcon } from '@mui/icons-material'; // Added DeleteIcon and EditIcon
import axios from 'axios';

function App() {
  const [tasks, setTasks] = useState([]);
  const [newTask, setNewTask] = useState({ title: '', description: '' });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [editingTask, setEditingTask] = useState(null); // State for task being edited

  // API base URL - will be different in production
  const API_URL = process.env.NODE_ENV === 'production'
    ? '/api'
    : 'http://localhost:5000/api';

  useEffect(() => {
    fetchTasks();
  }, []);

  const fetchTasks = async () => {
    try {
      setLoading(true);
      const response = await axios.get(`${API_URL}/tasks`);
      setTasks(response.data);
      setError('');
    } catch (err) {
      setError('Failed to fetch tasks');
      console.error('Error fetching tasks:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!newTask.title || !newTask.description) {
      setError('Please fill in all fields');
      return;
    }

    try {
      setLoading(true);
      if (editingTask) {
        // Update existing task
        await axios.put(`${API_URL}/tasks/${editingTask.id}`, newTask);
        setSuccess('Task updated successfully!');
        setEditingTask(null); // Clear editing state
      } else {
        // Add new task
        await axios.post(`${API_URL}/tasks`, newTask);
        setSuccess('Task added successfully!');
      }
      setNewTask({ title: '', description: '' });
      setError('');
      fetchTasks();
    } catch (err) {
      setError(`Failed to ${editingTask ? 'update' : 'add'} task`);
      console.error(`Error ${editingTask ? 'updating' : 'adding'} task:`, err);
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (taskId) => {
    try {
      setLoading(true);
      await axios.delete(`${API_URL}/tasks/${taskId}`);
      setSuccess('Task deleted successfully!');
      setError('');
      fetchTasks();
    } catch (err) {
      setError('Failed to delete task');
      console.error('Error deleting task:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleEdit = (task) => {
    setEditingTask(task);
    setNewTask({ title: task.title, description: task.description });
    setError(''); // Clear any previous errors when starting edit
    setSuccess(''); // Clear any previous success messages
  };

  const handleCancelEdit = () => {
    setEditingTask(null);
    setNewTask({ title: '', description: '' });
    setError('');
    setSuccess('');
  };

  return (
    <Box sx={{ flexGrow: 1, minHeight: '100vh', backgroundColor: '#e0f2f7' }}> {/* Light blue background */}
      <AppBar position="static" sx={{ backgroundColor: '#00796b' }}> {/* Darker teal AppBar */}
        <Toolbar>
          <AssignmentIcon sx={{ mr: 2 }} />
          <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
            TaskFlow Dashboard
          </Typography>
          <Typography variant="body2">
            Organize Your Workflow
          </Typography>
        </Toolbar>
      </AppBar>

      <Container maxWidth="lg" sx={{ mt: 4, pb: 4 }}>
        <Grid container spacing={4}>
          {/* Add/Edit Task Form */}
          <Grid item xs={12} md={6}>
            <Card>
              <CardContent>
                <Typography variant="h5" gutterBottom color="primary">
                  {editingTask ? 'Edit Task' : 'Add New Task'}
                </Typography>
                {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
                {success && <Alert severity="success" sx={{ mb: 2 }}>{success}</Alert>}

                <Box component="form" onSubmit={handleSubmit}>
                  <TextField
                    fullWidth
                    label="Task Title"
                    value={newTask.title}
                    onChange={(e) => setNewTask({ ...newTask, title: e.target.value })}
                    margin="normal"
                    variant="outlined"
                  />
                  <TextField
                    fullWidth
                    label="Task Description"
                    value={newTask.description}
                    onChange={(e) => setNewTask({ ...newTask, description: e.target.value })}
                    margin="normal"
                    variant="outlined"
                    multiline
                    rows={3}
                  />
                  <Button
                    type="submit"
                    variant="contained"
                    startIcon={loading ? <CircularProgress size={20} /> : (editingTask ? <EditIcon /> : <AddIcon />)}
                    disabled={loading}
                    fullWidth
                    sx={{ mt: 2, backgroundColor: '#00796b', '&:hover': { backgroundColor: '#004d40' } }}
                  >
                    {loading ? (editingTask ? 'Updating...' : 'Adding...') : (editingTask ? 'Update Task' : 'Add Task')}
                  </Button>
                  {editingTask && (
                    <Button
                      variant="outlined"
                      fullWidth
                      sx={{ mt: 1 }}
                      onClick={handleCancelEdit}
                      disabled={loading}
                    >
                      Cancel Edit
                    </Button>
                  )}
                </Box>
              </CardContent>
            </Card>
          </Grid>

          {/* Tasks List */}
          <Grid item xs={12} md={6}>
            <Card>
              <CardContent>
                <Typography variant="h5" gutterBottom color="primary">
                  Your Tasks ({tasks.length})
                </Typography>

                {loading && tasks.length === 0 ? (
                  <Box display="flex" justifyContent="center" p={3}>
                    <CircularProgress />
                  </Box>
                ) : tasks.length === 0 ? (
                  <Typography variant="body2" color="text.secondary" align="center" sx={{ py: 3 }}>
                    No tasks found. Add some tasks to get started!
                  </Typography>
                ) : (
                  <List>
                    {tasks.map((task) => (
                      <ListItem
                        key={task.id}
                        divider
                        secondaryAction={
                          <>
                            <IconButton edge="end" aria-label="edit" onClick={() => handleEdit(task)} sx={{ mr: 1 }}>
                              <EditIcon />
                            </IconButton>
                            <IconButton edge="end" aria-label="delete" onClick={() => handleDelete(task.id)}>
                              <DeleteIcon color="error" />
                            </IconButton>
                          </>
                        }
                      >
                        <ListItemText
                          primary={task.title}
                          secondary={task.description}
                        />
                      </ListItem>
                    ))}
                  </List>
                )}
              </CardContent>
            </Card>
          </Grid>

          {/* About TaskFlow */}
          <Grid item xs={12}>
            <Card sx={{ backgroundColor: '#e8f5e9' }}> {/* Light green background */}
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  💡 About TaskFlow
                </Typography>
                <Typography variant="body2" paragraph>
                  TaskFlow is a simple task management application designed to help you organize your daily activities.
                  It leverages a robust three-tier architecture for scalability and reliability:
                </Typography>
                <Box sx={{ ml: 2 }}>
                  <Typography variant="body2" paragraph>
                    <strong>Frontend:</strong> Built with React and Material-UI, providing an intuitive user interface.
                  </Typography>
                  <Typography variant="body2" paragraph>
                    <strong>Backend:</strong> A Node.js/Express API handles task creation, retrieval, updates, and deletion.
                  </Typography>
                  <Typography variant="body2" paragraph>
                    <strong>Database:</strong> Stores your tasks persistently, ensuring data integrity.
                  </Typography>
                </Box>
              </CardContent>
            </Card>
          </Grid>
        </Grid>
      </Container>
    </Box>
  );
}

export default App;
