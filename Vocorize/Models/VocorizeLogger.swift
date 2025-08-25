//
//  VocorizeLogger.swift
//  Vocorize
//
//  Centralized structured logging configuration using OSLog.
//  Replaces print() statements throughout the application.
//

import Foundation
import os

/// Centralized logging configuration for the Vocorize application
public enum VocorizeLogger {
    private static let subsystem = "com.tanvir.Vocorize"
    
    /// Logger for model download and loading operations
    public static let modelDownload = Logger(subsystem: subsystem, category: "ModelDownload")
    
    /// Logger for audio recording operations
    public static let recording = Logger(subsystem: subsystem, category: "Recording")
    
    /// Logger for clipboard and pasteboard operations
    public static let pasteboard = Logger(subsystem: subsystem, category: "Pasteboard")
    
    /// Logger for sound effect operations
    public static let soundEffect = Logger(subsystem: subsystem, category: "SoundEffect")
    
    /// Logger for general app lifecycle events
    public static let app = Logger(subsystem: subsystem, category: "App")
    
    /// Logger for key event monitoring (already exists, kept for consistency)
    public static let keyEventMonitor = Logger(subsystem: subsystem, category: "KeyEventMonitor")
}