const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

// Database connection
const pool = new Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'taskflow_db', // Changed database name
  password: process.env.DB_PASSWORD || 'password',
  port: process.env.DB_PORT || 5432,
  // --- START EDIT HERE ---
  ssl: {
    // This tells node-postgres to require SSL encryption
    require: true,
    // This setting means the client will not verify the server's certificate chain.
    // Use this for development/testing to get connected.
    // For production, it's strongly recommended to set this to `true`
    // and provide the RDS CA certificate bundle to `ca: fs.readFileSync('/path/to/rds-ca-bundle.pem')`
    rejectUnauthorized: false 
  }
  // --- END EDIT HERE ---
});

// Middleware
app.use(helmet());
app.use(morgan('combined'));
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Initialize database
const initializeDatabase = async () => {
  try {
    const client = await pool.connect();

    // Create tasks table if it doesn't exist
    await client.query(`
      CREATE TABLE IF NOT EXISTS tasks (
        id SERIAL PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        description TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    console.log('Database initialized successfully with tasks table');
    client.release();
  } catch (err) {
    console.error('Database initialization error:', err);
  }
};

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development'
  });
});

// API Routes

// Get all tasks
app.get('/api/tasks', async (req, res) => { // Changed from /api/users to /api/tasks
  try {
    const result = await pool.query('SELECT * FROM tasks ORDER BY created_at DESC'); // Changed table name
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching tasks:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get task by ID
app.get('/api/tasks/:id', async (req, res) => { // Changed from /api/users/:id to /api/tasks/:id
  try {
    const { id } = req.params;
    const result = await pool.query('SELECT * FROM tasks WHERE id = $1', [id]); // Changed table name

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error fetching task:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create new task
app.post('/api/tasks', async (req, res) => { // Changed from /api/users to /api/tasks
  try {
    const { title, description } = req.body; // Changed from name, email to title, description

    if (!title || !description) { // Updated validation
      return res.status(400).json({ error: 'Title and description are required' });
    }

    const result = await pool.query(
      'INSERT INTO tasks (title, description) VALUES ($1, $2) RETURNING *', // Changed table and columns
      [title, description]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error creating task:', err);

    // Removed unique violation check for email as description doesn't need to be unique
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update task
app.put('/api/tasks/:id', async (req, res) => { // Changed from /api/users/:id to /api/tasks/:id
  try {
    const { id } = req.params;
    const { title, description } = req.body; // Changed from name, email to title, description

    if (!title || !description) { // Updated validation
      return res.status(400).json({ error: 'Title and description are required' });
    }

    const result = await pool.query(
      'UPDATE tasks SET title = $1, description = $2 WHERE id = $3 RETURNING *', // Changed table and columns
      [title, description, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error updating task:', err);

    // Removed unique violation check for email
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete task
app.delete('/api/tasks/:id', async (req, res) => { // Changed from /api/users/:id to /api/tasks/:id
  try {
    const { id } = req.params;

    const result = await pool.query('DELETE FROM tasks WHERE id = $1 RETURNING *', [id]); // Changed table name

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }

    res.json({ message: 'Task deleted successfully' }); // Changed message
  } catch (err) {
    console.error('Error deleting task:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Database stats endpoint - updated to reflect task_count
app.get('/api/stats', async (req, res) => {
  try {
    const result = await pool.query('SELECT COUNT(*) as task_count FROM tasks'); // Changed count column
    const dbResult = await pool.query('SELECT version()');

    res.json({
      task_count: parseInt(result.rows[0].task_count), // Changed to task_count
      database_version: dbResult.rows[0].version,
      backend_version: '1.0.0',
      uptime: process.uptime()
    });
  } catch (err) {
    console.error('Error fetching stats:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Start server
const startServer = async () => {
  await initializeDatabase();

  app.listen(PORT, () => {
    console.log(`🚀 TaskFlow Backend server running on port ${PORT}`); // Updated log message
    console.log(`📊 Health check: http://localhost:${PORT}/health`);
    console.log(`🔗 API base URL: http://localhost:${PORT}/api`);
  });
};

// Handle graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received. Shutting down gracefully...');
  pool.end(() => {
    console.log('Database pool closed');
    process.exit(0);
  });
});

startServer().catch(console.error);
