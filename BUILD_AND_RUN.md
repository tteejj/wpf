# WPF Task Manager - Build and Run Guide

## Prerequisites
- .NET 8.0 SDK or later
- Windows environment (WPF requires Windows)

## Building the Application

### Debug Build (Recommended for development)
```bash
dotnet build --configuration Debug
```

### Release Build (For production)
```bash
dotnet build --configuration Release
```

## Running the Application

### Run directly (Debug mode)
```bash
dotnet run
```

### Run from built executable
```bash
# After building in Debug mode:
cd bin/Debug/net8.0-windows
./PraxisWpf.exe

# After building in Release mode:
cd bin/Release/net8.0-windows
./PraxisWpf.exe
```

## Debugging

### Enable Debug Logging
The application uses a logging system that creates log files with timestamps (e.g., `PraxisWpf_2025-08-18.log`).

To enable more detailed logging, edit `app-config.json`:
```json
{
  "logLevel": "Trace",
  "enableStackTrace": true,
  "enableThreadId": true
}
```

Log levels available:
- `Trace`: Most detailed (shows property access, method entry/exit)
- `Debug`: Detailed debugging info
- `Info`: General information (default)
- `Warning`: Warning messages
- `Error`: Error messages only
- `Critical`: Critical errors only

### Visual Studio Debugging
1. Open the project in Visual Studio
2. Set breakpoints where needed
3. Press F5 to run with debugger attached

### Logs Location
- **Development**: Log files are created in the project root
- **Runtime**: Log files are created next to the executable

## Keyboard Shortcuts Reference

| Key | Action |
|-----|--------|
| **N** | Create new project (always at top level) |
| **S** | Create new subtask (under selected item) |
| **E** | Enter/exit edit mode |
| **Delete** | Delete selected item |
| **Enter** | Confirm edit / Enter edit mode |
| **Escape** | Cancel edit mode |
| **Tab** | Move between edit fields (Name → Due Date → Priority) |
| **+/-** | Expand/collapse selected item |
| **Ctrl++/Ctrl+-** | Expand/collapse all items |
| **Ctrl+S** | Save data to JSON file |
| **Arrow Keys** | Navigate tree |

## Data Storage
- Data is stored in `data.json` in the application directory
- Automatic backup on each save
- Human-readable JSON format

## Troubleshooting

### Application won't start
1. Check if .NET 8.0 is installed: `dotnet --version`
2. Rebuild the application: `dotnet clean && dotnet build`
3. Check the log file for error messages

### Focus/Edit issues
- The application has extensive logging for focus issues
- Check log files for "🔥" markers which indicate focus-related events
- Edit mode only works when clicking or pressing E/Enter on a selected item

### JSON loading errors
- If JSON is corrupted, the app will start with empty data
- Check log files for JSON deserialization errors
- Manual JSON editing should follow the existing structure

### Performance issues
- Enable performance tracking by setting log level to "Trace"
- Look for performance markers in log files showing operation timing

## Development Notes

### Architecture
- MVVM pattern with clean separation
- No code-behind in XAML files
- Interface-based design for extensibility

### Adding new features
1. Models: Add to `/Models` folder
2. Views: Add XAML to `/Features` folder
3. ViewModels: Add logic to `/Features` folder
4. Services: Add to `/Services` folder
5. Themes: Add to `/Themes` folder

### Testing
- Manual testing through the UI
- Log files provide detailed tracing for debugging
- Focus on keyboard navigation as primary interaction method