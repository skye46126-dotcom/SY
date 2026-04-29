package com.example.life_os_app

class MainActivity : BaseFlutterHostActivity() {
    override val publishesDynamicShortcuts: Boolean = true
    override val fallbackRoute: String = "/today"
}
