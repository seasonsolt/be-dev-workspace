#!/bin/bash

# Ginkgoo AI Microservices Environment Variables Quick Setup Script
# Used to quickly copy .env.example to .env files

echo "🚀 Ginkgoo AI Microservices Environment Variables Setup"
echo "=================================="

# Service directory list
services=(
    "be-core-identity"
    "be-core-workspace"
    "be-legal-case"
    "be-core-gateway"
    "be-core-storage"
    "be-core-messaging"
    "be-core-intelligence"
)

echo ""
echo "📋 Will set up environment variables for the following services:"
for service in "${services[@]}"; do
    echo "  - $service"
done

echo ""
read -p "Continue setup? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Setup cancelled"
    exit 1
fi

echo ""
echo "🔧 Starting environment variable files setup..."

for service in "${services[@]}"; do
    if [ -d "$service" ]; then
        echo "  Processing $service..."
        
        if [ -f "$service/.env.example" ]; then
            if [ -f "$service/.env" ]; then
                echo "    ⚠️  .env file already exists, skipping $service"
            else
                cp "$service/.env.example" "$service/.env"
                echo "    ✅ Created $service/.env"
            fi
        else
            echo "    ❌ Cannot find $service/.env.example"
        fi
    else
        echo "  ⚠️  Directory does not exist: $service"
    fi
done

echo ""
echo "✨ Setup completed!"
echo ""
echo "📝 Next, you need to manually edit each service's .env file and fill in actual configuration values:"
echo ""

for service in "${services[@]}"; do
    if [ -f "$service/.env" ]; then
        echo "  nano $service/.env"
    fi
done

echo ""
echo "🔑 Important reminders:"
echo "  1. Fill in database password (POSTGRES_PASSWORD)"
echo "  2. Fill in Redis password (if using)"
echo "  3. Fill in AI API keys (OPENAI_API_KEY etc.)"
echo "  4. Fill in email service configuration"
echo "  5. Check for port conflicts"
echo ""
echo "📚 View detailed documentation: SPRING_BOOT_DOTENV_GUIDE.md"
echo "🌐 Environment configuration overview: ENVIRONMENT_CONFIGURATION.md"