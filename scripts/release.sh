#!/bin/bash

# Focus Quest - Local Release Script
# This script builds the app for multiple platforms and creates a GitHub release

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="focus_quest"
VERSION=""
BUILD_NUMBER=""
RELEASE_TAG=""
PRERELEASE=true  # Prerelease by default (beta)
GITHUB_REPO=""

# Output directory for builds
BUILD_OUTPUT_DIR="build/releases"

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Parse version from pubspec.yaml
get_version_from_pubspec() {
    VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)
    BUILD_NUMBER=$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f2)
    
    if [ -z "$VERSION" ]; then
        print_error "Could not parse version from pubspec.yaml"
        exit 1
    fi
    
    print_info "Version: $VERSION+$BUILD_NUMBER"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Flutter
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter is not installed or not in PATH"
        exit 1
    fi
    print_success "Flutter found: $(flutter --version | head -n 1)"
    
    # Check GitHub CLI
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed"
        echo "Install it with: brew install gh"
        exit 1
    fi
    print_success "GitHub CLI found"
    
    # Check if logged in to GitHub
    if ! gh auth status &> /dev/null; then
        print_error "Not logged in to GitHub CLI"
        echo "Run: gh auth login"
        exit 1
    fi
    print_success "GitHub CLI authenticated"
    
    # Get GitHub repo from git remote
    GITHUB_REPO=$(git remote get-url origin 2>/dev/null | sed 's/.*github.com[:/]\(.*\)\.git/\1/' | sed 's/.*github.com[:/]\(.*\)/\1/')
    if [ -z "$GITHUB_REPO" ]; then
        print_error "Could not determine GitHub repository from git remote"
        exit 1
    fi
    print_success "GitHub repo: $GITHUB_REPO"
}

# Clean previous builds
clean_builds() {
    print_header "Cleaning Previous Builds"
    
    rm -rf "$BUILD_OUTPUT_DIR"
    flutter clean
    mkdir -p "$BUILD_OUTPUT_DIR"
    print_success "Cleaned previous builds"
}

# Get dependencies
get_dependencies() {
    print_header "Getting Dependencies"
    
    flutter pub get
    print_success "Dependencies fetched"
}

# Build Android APK
build_android_apk() {
    print_header "Building Android APK"
    
    flutter build apk --release --build-name="$VERSION" --build-number="$BUILD_NUMBER"
    
    if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
        cp "build/app/outputs/flutter-apk/app-release.apk" "$BUILD_OUTPUT_DIR/${APP_NAME}-${VERSION}-android.apk"
        print_success "Android APK built: ${APP_NAME}-${VERSION}-android.apk"
    else
        print_error "Android APK build failed"
        return 1
    fi
}

# Build Android App Bundle (AAB)
build_android_aab() {
    print_header "Building Android App Bundle (AAB)"
    
    flutter build appbundle --release --build-name="$VERSION" --build-number="$BUILD_NUMBER"
    
    if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
        cp "build/app/outputs/bundle/release/app-release.aab" "$BUILD_OUTPUT_DIR/${APP_NAME}-${VERSION}-android.aab"
        print_success "Android AAB built: ${APP_NAME}-${VERSION}-android.aab"
    else
        print_error "Android AAB build failed"
        return 1
    fi
}

# Build macOS app
build_macos() {
    print_header "Building macOS App"
    
    flutter build macos --release --build-name="$VERSION" --build-number="$BUILD_NUMBER"
    
    # Find the app bundle (might be different from APP_NAME due to Spaces or casing)
    MACOS_APP_PATH=$(find "build/macos/Build/Products/Release" -maxdepth 1 -name "*.app" | head -n 1)
    
    if [ -n "$MACOS_APP_PATH" ] && [ -d "$MACOS_APP_PATH" ]; then
        MACOS_APP_NAME=$(basename "$MACOS_APP_PATH")
        # Create a DMG or ZIP
        cd "build/macos/Build/Products/Release"
        zip -r "../../../../../$BUILD_OUTPUT_DIR/${APP_NAME}-${VERSION}-macos.zip" "$MACOS_APP_NAME"
        cd - > /dev/null
        print_success "macOS app built: ${APP_NAME}-${VERSION}-macos.zip"
    else
        print_error "macOS build failed - Could not find .app bundle in build/macos/Build/Products/Release/"
        return 1
    fi
}

# Build iOS (unsigned IPA for testing)
build_ios() {
    print_header "Building iOS App (Unsigned)"
    
    flutter build ios --release --no-codesign --build-name="$VERSION" --build-number="$BUILD_NUMBER"
    
    IOS_APP="build/ios/iphoneos/Runner.app"
    if [ -d "$IOS_APP" ]; then
        # Create a payload and zip as IPA
        mkdir -p "$BUILD_OUTPUT_DIR/Payload"
        cp -r "$IOS_APP" "$BUILD_OUTPUT_DIR/Payload/"
        cd "$BUILD_OUTPUT_DIR"
        zip -r "${APP_NAME}-${VERSION}-ios-unsigned.ipa" Payload
        rm -rf Payload
        cd - > /dev/null
        print_success "iOS app built: ${APP_NAME}-${VERSION}-ios-unsigned.ipa"
    else
        print_error "iOS build failed"
        return 1
    fi
}

# Build Web
build_web() {
    print_header "Building Web App"
    
    flutter build web --release --build-name="$VERSION" --build-number="$BUILD_NUMBER"
    
    if [ -d "build/web" ]; then
        cd "build"
        zip -r "../$BUILD_OUTPUT_DIR/${APP_NAME}-${VERSION}-web.zip" web
        cd - > /dev/null
        print_success "Web app built: ${APP_NAME}-${VERSION}-web.zip"
    else
        print_error "Web build failed"
        return 1
    fi
}

# Build Linux
build_linux() {
    print_header "Building Linux App"
    
    flutter build linux --release --build-name="$VERSION" --build-number="$BUILD_NUMBER"
    
    if [ -d "build/linux/x64/release/bundle" ]; then
        cd "build/linux/x64/release"
        tar -czvf "../../../../$BUILD_OUTPUT_DIR/${APP_NAME}-${VERSION}-linux-x64.tar.gz" bundle
        cd - > /dev/null
        print_success "Linux app built: ${APP_NAME}-${VERSION}-linux-x64.tar.gz"
    else
        print_error "Linux build failed"
        return 1
    fi
}

# Build Windows
build_windows() {
    print_header "Building Windows App"
    
    flutter build windows --release --build-name="$VERSION" --build-number="$BUILD_NUMBER"
    
    if [ -d "build/windows/x64/runner/Release" ]; then
        cd "build/windows/x64/runner"
        zip -r "../../../../$BUILD_OUTPUT_DIR/${APP_NAME}-${VERSION}-windows-x64.zip" Release
        cd - > /dev/null
        print_success "Windows app built: ${APP_NAME}-${VERSION}-windows-x64.zip"
    else
        print_error "Windows build failed"
        return 1
    fi
}

# Create GitHub Release
create_github_release() {
    print_header "Creating GitHub Release"
    
    if [ "$PRERELEASE" = true ]; then
        RELEASE_TAG="v${VERSION}-beta"
        RELEASE_TITLE="Focus Quest ${VERSION} Beta"
        PRERELEASE_FLAG="--prerelease"
        VERSION_LABEL="(Beta)"
    else
        RELEASE_TAG="v${VERSION}"
        RELEASE_TITLE="Focus Quest ${VERSION}"
        PRERELEASE_FLAG=""
        VERSION_LABEL=""
    fi
    
    # Check if release already exists
    if gh release view "$RELEASE_TAG" --repo "$GITHUB_REPO" &> /dev/null; then
        print_warning "Release $RELEASE_TAG already exists"
        read -p "Do you want to delete and recreate it? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            gh release delete "$RELEASE_TAG" --repo "$GITHUB_REPO" --yes
            print_info "Deleted existing release"
        else
            print_error "Aborting release"
            exit 1
        fi
    fi
    
    # Generate release notes
    RELEASE_NOTES="## Focus Quest ${VERSION} ${VERSION_LABEL}

### What's New
- $([ "$PRERELEASE" = true ] && echo "Beta release for testing" || echo "Stable release")

### Downloads
- **Android**: Download the APK for direct installation
- **macOS**: Download and extract the ZIP, then drag to Applications
- **iOS**: Unsigned IPA (requires TestFlight or manual signing)
- **Web**: Deploy the web folder to any static hosting

### Installation Notes
- **Android**: Enable 'Install from unknown sources' in settings
- **macOS**: Right-click and select 'Open' to bypass Gatekeeper on first run

---
Built on: $(date)
"

    # Create release with all artifacts
    print_info "Creating release $RELEASE_TAG..."
    
    RELEASE_FILES=()
    for file in "$BUILD_OUTPUT_DIR"/*; do
        if [ -f "$file" ]; then
            RELEASE_FILES+=("$file")
        fi
    done
    
    if [ ${#RELEASE_FILES[@]} -eq 0 ]; then
        print_error "No build artifacts found in $BUILD_OUTPUT_DIR"
        exit 1
    fi
    
    # Run gh release create
    # Use array for arguments to handle optional flags and filenames correctly
    gh_args=(release create "$RELEASE_TAG" \
        --repo "$GITHUB_REPO" \
        --title "$RELEASE_TITLE" \
        --notes "$RELEASE_NOTES")
    
    if [ "$PRERELEASE" = true ]; then
        gh_args+=("--prerelease")
    fi
    
    # Add files
    gh_args+=("${RELEASE_FILES[@]}")
    
    gh "${gh_args[@]}"
    
    print_success "GitHub release created: $RELEASE_TAG"
    print_info "View release at: https://github.com/$GITHUB_REPO/releases/tag/$RELEASE_TAG"
}

# Show usage
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --all           Build all platforms (Android, macOS, iOS, Web)"
    echo "  --android       Build Android APK and AAB"
    echo "  --macos         Build macOS app"
    echo "  --ios           Build iOS app (unsigned)"
    echo "  --web           Build web app"
    echo "  --linux         Build Linux app"
    echo "  --windows       Build Windows app"
    echo "  --prod          Create a production release (non-beta, no -beta tag)"
    echo "  --release-only  Skip builds, only create GitHub release from existing artifacts"
    echo "  --no-clean      Skip cleaning previous builds"
    echo "  --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --all                    # Build all and release (beta)"
    echo "  $0 --all --prod             # Build all and release (production)"
    echo "  $0 --android --macos        # Build only Android and macOS"
    echo "  $0 --release-only           # Create release from existing builds"
}

# Main script
main() {
    cd "$(dirname "$0")/.."
    
    BUILD_ANDROID=false
    BUILD_MACOS=false
    BUILD_IOS=false
    BUILD_WEB=false
    BUILD_LINUX=false
    BUILD_WINDOWS=false
    RELEASE_ONLY=false
    NO_CLEAN=false
    
    # Parse arguments
    if [ $# -eq 0 ]; then
        usage
        exit 0
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                BUILD_ANDROID=true
                BUILD_MACOS=true
                BUILD_IOS=true
                BUILD_WEB=true
                shift
                ;;
            --android)
                BUILD_ANDROID=true
                shift
                ;;
            --macos)
                BUILD_MACOS=true
                shift
                ;;
            --ios)
                BUILD_IOS=true
                shift
                ;;
            --web)
                BUILD_WEB=true
                shift
                ;;
            --linux)
                BUILD_LINUX=true
                shift
                ;;
            --windows)
                BUILD_WINDOWS=true
                shift
                ;;
            --release-only)
                RELEASE_ONLY=true
                shift
                ;;
            --no-clean)
                NO_CLEAN=true
                shift
                ;;
            --prod)
                PRERELEASE=false
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    if [ "$PRERELEASE" = true ]; then
        print_header "Focus Quest Beta Release"
    else
        print_header "Focus Quest Production Release"
    fi
    
    check_prerequisites
    get_version_from_pubspec
    
    if [ "$RELEASE_ONLY" = false ]; then
        if [ "$NO_CLEAN" = false ]; then
            clean_builds
        else
            mkdir -p "$BUILD_OUTPUT_DIR"
        fi
        
        get_dependencies
        
        # Build selected platforms
        if [ "$BUILD_ANDROID" = true ]; then
            build_android_apk || true
            build_android_aab || true
        fi
        
        if [ "$BUILD_MACOS" = true ]; then
            build_macos || true
        fi
        
        if [ "$BUILD_IOS" = true ]; then
            build_ios || true
        fi
        
        if [ "$BUILD_WEB" = true ]; then
            build_web || true
        fi
        
        if [ "$BUILD_LINUX" = true ]; then
            build_linux || true
        fi
        
        if [ "$BUILD_WINDOWS" = true ]; then
            build_windows || true
        fi
    fi
    
    # Show built artifacts
    print_header "Build Artifacts"
    if [ -d "$BUILD_OUTPUT_DIR" ] && [ "$(ls -A $BUILD_OUTPUT_DIR 2>/dev/null)" ]; then
        ls -lh "$BUILD_OUTPUT_DIR"
    else
        print_warning "No build artifacts found"
    fi
    
    # Ask to create release
    echo ""
    read -p "Create GitHub release with these artifacts? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_github_release
    else
        print_info "Skipping GitHub release. Artifacts are in: $BUILD_OUTPUT_DIR"
    fi
    
    print_header "Done!"
}

main "$@"
