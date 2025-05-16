#!/bin/bash

# Project creation setup

echo "======================================================"
echo "  Project Development Environment Setup"
echo "======================================================"

choose_languages() {
    echo "Choose a programming language:"
    echo "    [1] Python"
    echo "    [2] C/C++"
    echo "    [3] Go"
    
    read -r chosen_lang
    
    if [ "$chosen_lang" == "1" ]; then
        echo "Python selected"
        language="python"
    elif [ "$chosen_lang" == "2" ]; then
        echo "C/C++ selected"
        language="c"
    elif [ "$chosen_lang" == "3" ]; then
        echo "Go selected"
        language="go"
    else
        echo "Invalid choice. Defaulting to Python."
        language="python"
    fi
}

dependencies_setup() {
    echo "======================================================"
    echo "  Dependencies Setup"
    echo "======================================================"
    echo ""
    read -p "Is your system a Website? [y/N]: " webQ
    read -p "Will you use Docker? [y/N]: " dockerQ
    
    # Convert to lowercase for easier comparison
    webQ=$(echo "$webQ" | tr '[:upper:]' '[:lower:]')
    dockerQ=$(echo "$dockerQ" | tr '[:upper:]' '[:lower:]')
    
    # Docker setup if selected
    if [ "$dockerQ" == "y" ]; then
        setup_docker
    fi
    
    clear
}

setup_docker() {
    echo "Setting up Docker environment..."
    
    # Create Dockerfile
    cat > Dockerfile << EOF
FROM ${language}-base:latest

WORKDIR /app

# Add language-specific configurations here
# For example, for Python:
# COPY requirements.txt .
# RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Default command
CMD ["echo", "Container is running"]
EOF

    # Create docker-compose.yml if it's a web project
    if [ "$webQ" == "y" ]; then
        cat > docker-compose.yml << EOF
version: '3'

services:
  app:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - .:/app
    depends_on:
      - db
  
  db:
    image: postgres:latest
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
      POSTGRES_DB: ${projName}_db
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
EOF
    fi
    
    echo "Docker setup completed."
}

create_directories() {
    echo "======================================================"
    echo "  Creating project directory structure"
    echo "======================================================"
    
    # Base directories for all projects
    mkdir -p src
    mkdir -p tests
    mkdir -p docs
    
    # Language-specific directories
    case $language in
        "python")
            mkdir -p src/utils
            touch src/__init__.py
            touch src/utils/__init__.py
            touch requirements.txt
            ;;
        "c")
            mkdir -p src/include
            mkdir -p build
            touch Makefile
            ;;
        "go")
            mkdir -p cmd
            mkdir -p pkg
            mkdir -p internal
            touch go.mod
            ;;
    esac
    
    # Website-specific directories
    if [ "$webQ" == "y" ]; then
        mkdir -p frontend/src/{assets,components,views,services,utils}
        mkdir -p backend/src/{api,config,middleware,models,services,utils}
        mkdir -p database/{migrations,schemas,scripts}
        
        # Create basic README file
        cat > README.md << EOF
# $projName

## Setup Instructions

### Prerequisites
- List of prerequisites

### Installation
1. Clone the repository
2. Install dependencies
3. Run the application

## Project Structure
- \`frontend/\`: Contains frontend code
- \`backend/\`: Contains backend code
- \`database/\`: Contains database-related files
EOF
    else
        # Create a basic README file for non-web projects
        cat > README.md << EOF
# $projName

## Setup Instructions

### Prerequisites
- List of prerequisites

### Installation
1. Clone the repository
2. Install dependencies
3. Run the application

## Project Structure
- \`src/\`: Source code
- \`tests/\`: Test files
- \`docs/\`: Documentation
EOF
    fi
    
    echo "Directory structure created successfully."
}

initialize_git() {
    echo "======================================================"
    echo "  Initializing Git repository"
    echo "======================================================"
    
    git init
    
    # Create .gitignore based on language
    case $language in
        "python")
            cat > .gitignore << EOF
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
*.egg-info/
.installed.cfg
*.egg
venv/
.env
EOF
            ;;
        "c")
            cat > .gitignore << EOF
# C/C++
*.o
*.ko
*.obj
*.elf
*.exe
*.out
*.app
*.i*86
*.x86_64
*.hex
build/
EOF
            ;;
        "go")
            cat > .gitignore << EOF
# Go
/vendor/
/Godeps/
*.exe
*.exe~
*.dll
*.so
*.dylib
*.test
*.out
go.work
EOF
            ;;
    esac
    
    # Add Docker-related entries if Docker is being used
    if [ "$dockerQ" == "y" ]; then
        cat >> .gitignore << EOF

# Docker
.dockerignore
EOF
    fi
    
    git add .
    git commit -m "Initial commit: Project structure setup"
    
    echo "Git repository initialized successfully."
}

main() {
    echo "======================================================"
    echo "  Starting Project Setup"
    echo "======================================================"
    
    read -p "Project Name: " projName
    
    # Create project directory
    mkdir -p "$projName"
    cd "$projName" || exit
    
    choose_languages
    dependencies_setup
    create_directories
    initialize_git
    
    echo "======================================================"
    echo "  Project '$projName' has been set up successfully!"
    echo "  Language: $language"
    echo "  Web Project: $webQ"
    echo "  Using Docker: $dockerQ"
    echo "======================================================"
    echo "  You can now start developing your project."
    echo "  cd $projName"
    echo "======================================================"
}

# Execute the main function
main
