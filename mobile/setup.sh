#!/bin/bash

# Rehab Exercise Tracker Mobile App Setup Script

echo "🏥 Setting up Rehab Exercise Tracker Mobile App..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js 18+ and try again."
    exit 1
fi

# Check if Expo CLI is installed
if ! command -v expo &> /dev/null; then
    echo "📱 Installing Expo CLI..."
    npm install -g @expo/cli
fi

# Install project dependencies
echo "📦 Installing project dependencies..."
npm install --legacy-peer-deps

# Check if backend is running (optional)
echo "🔍 Checking backend connectivity..."
if curl -f -s http://localhost:4000/api/health > /dev/null 2>&1; then
    echo "✅ Backend is running and accessible"
else
    echo "⚠️  Backend not detected at http://localhost:4000"
    echo "   The app will use mock data for development"
fi

# Create asset files if they don't exist
echo "🎨 Setting up assets..."
if [ ! -f "assets/icon.png" ]; then
    echo "📱 Note: Add your app icon to assets/icon.png (1024x1024)"
fi

if [ ! -f "assets/splash.png" ]; then
    echo "🌟 Note: Add your splash screen to assets/splash.png (1284x2778)"
fi

echo ""
echo "🎉 Setup complete! You can now start the development server:"
echo ""
echo "   npm start      # Start Expo development server"
echo "   npm run ios    # Run on iOS simulator"  
echo "   npm run android # Run on Android emulator"
echo ""
echo "📋 Next steps:"
echo "   1. Update API endpoint in src/services/ApiService.ts"
echo "   2. Configure camera permissions for your platform"
echo "   3. Add app icons and splash screens to assets/"
echo "   4. Test authentication with your backend"
echo ""
echo "📚 For more help, see the README.md file"