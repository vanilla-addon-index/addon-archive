# IntelliSense

IntelliSense is a WoW 1.12.1 addon that provides auto-completion for chat messages.
It learns from your typing patterns and suggests word completions as you type.

## Logic

IntelliSense uses a 5-layered prediction system:

### 1. Base Vocabulary
Built-in dictionary of WoW-specific terms, locations, and common English words for initial suggestions.

### 2. Learned Words
Custom vocabulary expansion through asterisk notation (*word*) for domain-specific terms.

### 3. Usage Statistics
Frequency-based ranking system that prioritizes commonly used words in suggestions.

### 4. Bigram Context
Two-word relationship tracking ("going" → "to") for contextual predictions.

### 5. Trigram Context
Three-word sequence learning ("I need to" → "go") for advanced contextual accuracy.

## Features

### 1. Auto-Completion
Real-time word suggestions appear as you type in chat with intelligent context awareness.

### 2. Learning System
Teach new words by wrapping them in asterisks (*word*) and automatic pattern recognition.

### 3. Statistics Dashboard
Monitor your typing efficiency with detailed stats including completions used, characters saved, efficiency score, and most frequently used words. The efficiency score shows your completion rate - how often you accept suggestions when shown.

### 4. Word Management
View and manage your learned vocabulary through the interface. Remove unwanted words and track your personal dictionary growth.

### 5. Auto-Capitalize
Optional grammar correction that automatically capitalizes words at the start of sentences and after punctuation.

## Preview

![IntelliSense Interface](https://i.ibb.co/wNKc90YY/Download.png)

![Typing Demo](https://i.ibb.co/CKq3bQG4/1.gif)

## Installation

1. Extract to your `Interface/AddOns/` folder
2. Restart WoW
3. Type `/int` to open the configuration interface

## Commands

- `/int` - Open configuration interface
- `/int reset` - Reset all data and reload UI

## Usage

- Type normally in chat - suggestions appear automatically
- Press **Tab** to accept a suggestion
- Wrap new words in asterisks to teach: `*example*`