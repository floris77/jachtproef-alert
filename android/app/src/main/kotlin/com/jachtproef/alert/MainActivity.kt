package com.jachtproef.alert

import io.flutter.embedding.android.FlutterActivity
import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }
} 