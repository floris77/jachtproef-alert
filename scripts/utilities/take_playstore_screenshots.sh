#!/bin/bash

# Google Play Store Screenshot Requirements:
# - Each side must be between 1080px and 7680px  
# - Aspect ratio can't exceed 2.30:1 (landscape) or 1:2.30 (portrait)
# - Tablet screenshots need minimum 1080px on shortest side

echo "📱 Taking Google Play Store Screenshots..."
echo "Requirements: 1080px-7680px per side, max 2.30:1 aspect ratio"

# Create directory for Play Store screenshots
mkdir -p store_assets/playstore_screenshots

# Get device info
echo "📋 Checking connected devices..."
adb devices

# Function to take and resize screenshot
take_screenshot() {
    local filename="$1"
    local width="$2"
    local height="$3"
    local description="$4"
    
    echo "📸 Taking screenshot: $description"
    echo "   Target size: ${width}x${height}px"
    
    # Take screenshot from device
    adb exec-out screencap -p > "store_assets/playstore_screenshots/temp_${filename}.png"
    
    # Resize to exact dimensions using sips (macOS built-in)
    sips -z $height $width "store_assets/playstore_screenshots/temp_${filename}.png" --out "store_assets/playstore_screenshots/${filename}.png"
    
    # Clean up temp file
    rm "store_assets/playstore_screenshots/temp_${filename}.png"
    
    echo "   ✅ Saved: store_assets/playstore_screenshots/${filename}.png"
}

echo ""
echo "🎯 Ready to take screenshots!"
echo "Please navigate to different screens in your app, then press ENTER to take each screenshot:"
echo ""

# Tablet screenshots (landscape) - 1920x1080 (16:9 ratio = 1.78:1, well under 2.30:1)
echo "📱 TABLET SCREENSHOTS (Landscape 1920x1080)"
echo "1. Navigate to the main hunting exams list screen"
read -p "Press ENTER when ready for screenshot 1..."
take_screenshot "tablet_landscape_1_main_list" 1920 1080 "Main hunting exams list"

echo "2. Navigate to a specific exam detail page"
read -p "Press ENTER when ready for screenshot 2..."
take_screenshot "tablet_landscape_2_exam_detail" 1920 1080 "Exam detail page"

echo "3. Navigate to the calendar/agenda view"
read -p "Press ENTER when ready for screenshot 3..."
take_screenshot "tablet_landscape_3_calendar" 1920 1080 "Calendar/agenda view"

echo "4. Navigate to search/filter results"
read -p "Press ENTER when ready for screenshot 4..."
take_screenshot "tablet_landscape_4_search_filter" 1920 1080 "Search and filter results"

echo "5. Navigate to notifications or settings"
read -p "Press ENTER when ready for screenshot 5..."
take_screenshot "tablet_landscape_5_settings" 1920 1080 "Settings or notifications"

# Phone screenshots (portrait) - 1080x1920 (9:16 ratio = 1:1.78, well under 1:2.30)
echo ""
echo "📱 PHONE SCREENSHOTS (Portrait 1080x1920)"
echo "If you have a phone emulator available, switch to it now"
echo "Otherwise, we can rotate the tablet to portrait mode"
read -p "Press ENTER to continue or Ctrl+C to skip phone screenshots..."

echo "1. Main hunting exams list (phone portrait)"
read -p "Press ENTER when ready..."
take_screenshot "phone_portrait_1_main_list" 1080 1920 "Main list (phone)"

echo "2. Exam detail page (phone portrait)"
read -p "Press ENTER when ready..."
take_screenshot "phone_portrait_2_exam_detail" 1080 1920 "Exam detail (phone)"

echo "3. Calendar view (phone portrait)"
read -p "Press ENTER when ready..."
take_screenshot "phone_portrait_3_calendar" 1080 1920 "Calendar (phone)"

echo ""
echo "🎉 All screenshots taken!"
echo "📁 Location: store_assets/playstore_screenshots/"
echo ""
echo "📋 File sizes and ratios:"
for file in store_assets/playstore_screenshots/*.png; do
    if [ -f "$file" ]; then
        size=$(sips -g pixelWidth -g pixelHeight "$file" | grep -E 'pixelWidth|pixelHeight' | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
        echo "   $(basename "$file"): ${size}px"
    fi
done

echo ""
echo "✅ These screenshots meet Google Play Store requirements:"
echo "   - All sides between 1080px and 7680px ✓"
echo "   - Aspect ratios under 2.30:1 ✓"
echo "   - High quality for store listing ✓" 