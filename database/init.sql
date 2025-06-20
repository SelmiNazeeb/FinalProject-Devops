-- Create tasks table
CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL, -- Changed from name to title, increased length for task titles
    description TEXT,             -- Changed from email to description, using TEXT for longer content
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO tasks (title, description) VALUES
    ('Plan Project Kickoff', 'Schedule meeting with team, define agenda, and prepare presentation slides.'),
    ('Develop Frontend UI', 'Implement the main dashboard layout and task input form using Material-UI.'),
    ('Set Up Backend API', 'Create REST endpoints for CRUD operations on tasks and connect to the database.'),
    ('Write Unit Tests', 'Develop tests for backend API routes and frontend components.'),
    ('Prepare Deployment Script', 'Automate deployment to AWS EKS using Terraform or Kubernetes manifests.')
ON CONFLICT (id) DO NOTHING; -- Changed ON CONFLICT clause to use primary key 'id' to prevent errors on re-run if IDs are already present.

-- Create index for better performance (for commonly queried columns)
CREATE INDEX IF NOT EXISTS idx_tasks_created_at ON tasks(created_at);
CREATE INDEX IF NOT EXISTS idx_tasks_title ON tasks(title); -- New index on title for searches/sorting

-- Grant permissions
GRANT ALL PRIVILEGES ON TABLE tasks TO postgres;
GRANT USAGE, SELECT ON SEQUENCE tasks_id_seq TO postgres;
