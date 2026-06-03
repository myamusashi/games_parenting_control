#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Flutter Apps Folder Structure Setup${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Function to create folder structure
create_folder_structure() {
    local app_name=$1
    local app_path=$2
    
    echo -e "${YELLOW}Setting up ${app_name}...${NC}\n"
    
    # Create lib subdirectories
    mkdir -p "${app_path}/lib/screens/auth"
    mkdir -p "${app_path}/lib/screens/games"
    mkdir -p "${app_path}/lib/screens/dashboard"
    mkdir -p "${app_path}/lib/screens/settings"
    mkdir -p "${app_path}/lib/models"
    mkdir -p "${app_path}/lib/services"
    mkdir -p "${app_path}/lib/widgets"
    mkdir -p "${app_path}/lib/utils"
    
    echo -e "${GREEN}✓ Created lib directory structure${NC}"
}

# Setup Parent App
echo -e "${BLUE}1. Setting up gamesbox_parent...${NC}\n"
create_folder_structure "gamesbox_parent" "gamesbox_parent"

# Create parent app specific screens
mkdir -p "gamesbox_parent/lib/screens/time_limits"

echo -e "${GREEN}✓ Parent app directories created:${NC}"
echo "   - lib/screens/auth/"
echo "   - lib/screens/games/"
echo "   - lib/screens/time_limits/"
echo "   - lib/screens/dashboard/"
echo "   - lib/screens/settings/"
echo "   - lib/models/"
echo "   - lib/services/"
echo "   - lib/widgets/"
echo "   - lib/utils/"
echo ""

# Setup Kids App
echo -e "${BLUE}2. Setting up gamesbox_kids...${NC}\n"
create_folder_structure "gamesbox_kids" "gamesbox_kids"

echo -e "${GREEN}✓ Kids app directories created:${NC}"
echo "   - lib/screens/auth/"
echo "   - lib/screens/games/"
echo "   - lib/screens/dashboard/"
echo "   - lib/screens/settings/"
echo "   - lib/models/"
echo "   - lib/services/"
echo "   - lib/widgets/"
echo "   - lib/utils/"
echo ""

# Create .gitkeep files to preserve empty directories in git
echo -e "${YELLOW}Creating .gitkeep files for git tracking...${NC}\n"

# Parent app .gitkeep files
touch gamesbox_parent/lib/screens/auth/.gitkeep
touch gamesbox_parent/lib/screens/games/.gitkeep
touch gamesbox_parent/lib/screens/time_limits/.gitkeep
touch gamesbox_parent/lib/screens/dashboard/.gitkeep
touch gamesbox_parent/lib/screens/settings/.gitkeep
touch gamesbox_parent/lib/models/.gitkeep
touch gamesbox_parent/lib/services/.gitkeep
touch gamesbox_parent/lib/widgets/.gitkeep
touch gamesbox_parent/lib/utils/.gitkeep

# Kids app .gitkeep files
touch gamesbox_kids/lib/screens/auth/.gitkeep
touch gamesbox_kids/lib/screens/games/.gitkeep
touch gamesbox_kids/lib/screens/dashboard/.gitkeep
touch gamesbox_kids/lib/screens/settings/.gitkeep
touch gamesbox_kids/lib/models/.gitkeep
touch gamesbox_kids/lib/services/.gitkeep
touch gamesbox_kids/lib/widgets/.gitkeep
touch gamesbox_kids/lib/utils/.gitkeep

echo -e "${GREEN}✓ .gitkeep files created${NC}\n"

# Display tree structure
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Folder Structure Overview${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${YELLOW}gamesbox_parent/${NC}"
echo "├── lib/"
echo "│   ├── screens/"
echo "│   │   ├── auth/"
echo "│   │   ├── games/"
echo "│   │   ├── time_limits/"
echo "│   │   ├── dashboard/"
echo "│   │   └── settings/"
echo "│   ├── models/"
echo "│   ├── services/"
echo "│   ├── widgets/"
echo "│   └── utils/"
echo ""

echo -e "${YELLOW}gamesbox_kids/${NC}"
echo "├── lib/"
echo "│   ├── screens/"
echo "│   │   ├── auth/"
echo "│   │   ├── games/"
echo "│   │   ├── dashboard/"
echo "│   │   └── settings/"
echo "│   ├── models/"
echo "│   ├── services/"
echo "│   ├── widgets/"
echo "│   └── utils/"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete! ✓${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${BLUE}Next steps:${NC}"
echo "1. Update pubspec.yaml for gamesbox_kids:"
echo "   - Add: firebase_database, firebase_core, firebase_auth, mobile_scanner, otp"
echo ""
echo "2. Create models in lib/models/"
echo "3. Create services in lib/services/"
echo "4. Create screens in lib/screens/"
echo ""
echo -e "${YELLOW}Happy coding! 🚀${NC}\n"
