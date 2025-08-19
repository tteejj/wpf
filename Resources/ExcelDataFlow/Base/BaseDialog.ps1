# BaseDialog.ps1 - Base class for modal dialogs to eliminate code duplication
# COPIED FROM PRAXIS - ACTUAL WORKING VERSION

class BaseDialog : Screen {
    # Dialog properties
    [int]$DialogWidth = 50
    [int]$DialogHeight = 14
    [int]$DialogPadding = 1
    [int]$ButtonHeight = 3
    [int]$ButtonSpacing = 1
    [int]$MaxButtonWidth = 12
    [BorderType]$BorderType = [BorderType]::Rounded
    
    # Common buttons
    [MinimalButton]$PrimaryButton
    [MinimalButton]$SecondaryButton
    [string]$PrimaryButtonText = "OK"
    [string]$SecondaryButtonText = "Cancel"
    
    # Event handlers
    [scriptblock]$OnPrimary = {}
    [scriptblock]$OnSecondary = {}
    [scriptblock]$OnCreate = {}  # Legacy support
    [scriptblock]$OnCancel = {}  # Legacy support
    
    # Internal state
    hidden [hashtable]$_dialogBounds = @{}
    hidden [System.Collections.ArrayList]$_contentControls
    hidden [hashtable]$_contentLabels = @{}
    hidden [bool]$_initialized = $false
    [object]$EventBus
    
    # Layout components
    hidden [VerticalSplit]$_mainLayout
    hidden [Container]$_contentContainer
    hidden [HorizontalSplit]$_buttonLayout
    
    BaseDialog([string]$title) : base() {
        $this.Title = $title
        $this.DrawBackground = $false
        $this._contentControls = [System.Collections.ArrayList]::new()
    }
    
    BaseDialog([string]$title, [int]$width, [int]$height) : base() {
        $this.Title = $title
        $this.DrawBackground = $false
        $this.DialogWidth = $width
        $this.DialogHeight = $height
        $this._contentControls = [System.Collections.ArrayList]::new()
    }
    
    [void] OnInitialize() {
        # Prevent double initialization
        if ($this._initialized) {
            return
        }
        $this._initialized = $true
        
        # Call parent initialization to set Theme
        ([Screen]$this).OnInitialize()
        
        # Get EventBus (may not exist in standalone)
        if ($global:ServiceContainer -and $global:ServiceContainer.HasService('EventBus')) {
            $this.EventBus = $global:ServiceContainer.GetService('EventBus')
        }
        
        # Create layout structure
        $this.CreateLayoutStructure()
        
        # Create default buttons
        $this.CreateDefaultButtons()
        
        # Call derived class initialization
        $this.InitializeContent()
    }
    
    # Virtual method for derived classes to override
    [void] InitializeContent() {
        # Override in derived classes
    }
    
    [void] CreateLayoutStructure() {
        # Create main vertical split (content area + button area)
        $this._mainLayout = [VerticalSplit]::new()
        $this._mainLayout.ShowBorder = $false
        
        # Calculate split based on dialog height
        # Leave 3 lines for buttons (2 for button + 1 for spacing)
        $buttonHeightLocal = 3
        $contentHeightLocal = $this.DialogHeight - 3  # -2 for borders, -2 for title
        $splitRatio = [int](($contentHeightLocal * 100) / ($contentHeightLocal + $buttonHeightLocal))
        $this._mainLayout.SplitRatio = $splitRatio
        
        # Create content container
        $this._contentContainer = [Container]::new()
        $this._contentContainer.DrawBackground = $false
        $this._mainLayout.SetTopPane($this._contentContainer)
        
        # Create button container
        $buttonContainer = [Container]::new()
        $buttonContainer.DrawBackground = $false
        
        # Create horizontal split for buttons
        $this._buttonLayout = [HorizontalSplit]::new()
        $this._buttonLayout.ShowBorder = $false
        $this._buttonLayout.SplitRatio = 50  # Equal space for both buttons
        
        $buttonContainer.AddChild($this._buttonLayout)
        $this._mainLayout.SetBottomPane($buttonContainer)
        
        # Add main layout to dialog
        $this.AddChild($this._mainLayout)
    }
    
    [void] CreateDefaultButtons() {
        # Create primary button
        $this.PrimaryButton = [MinimalButton]::new($this.PrimaryButtonText)
        $this.PrimaryButton.IsDefault = $true
        $dialog = $this  # Capture reference
        $this.PrimaryButton.OnClick = {
            $dialog.HandlePrimaryAction()
        }.GetNewClosure()
        
        # Create secondary button
        $this.SecondaryButton = [MinimalButton]::new($this.SecondaryButtonText)
        $this.SecondaryButton.OnClick = {
            $dialog.HandleSecondaryAction()
        }.GetNewClosure()
        
        # Add buttons to layout instead of directly to dialog
        if ($this._buttonLayout) {
            $this._buttonLayout.SetLeftPane($this.PrimaryButton)
            $this._buttonLayout.SetRightPane($this.SecondaryButton)
        }
    }
    
    [void] AddContentControl([UIElement]$control) {
        $this.AddContentControl($control, -1)
    }
    
    [void] AddContentControl([UIElement]$control, [int]$tabIndex) {
        # Initialize the control if it hasn't been initialized
        if ($control -and $this.ServiceContainer) {
            $control.Initialize($this.ServiceContainer)
        }
        
        if ($tabIndex -gt 0) {
            $control.TabIndex = $tabIndex
        }
        
        # Position controls vertically based on their order
        $yOffset = 0
        foreach ($existing in $this._contentControls) {
            $yOffset += $existing.Height + 1  # +1 for spacing between fields
        }
        
        # Set control bounds within content container (relative positioning)
        # Controls will be positioned relative to their container, not absolute screen position
        $control.SetBounds(2, $yOffset, $this.DialogWidth - 6, $control.Height)
        
        # Add to content container instead of directly to dialog
        if ($this._contentContainer) {
            $this._contentContainer.AddChild($control)
        }
        $this._contentControls.Add($control) | Out-Null
    }
    
    [void] AddContentLabel([string]$text, [int]$section = 0) {
        # Store label for rendering in the dialog
        if (-not $this._contentLabels) {
            $this._contentLabels = @{}
        }
        $this._contentLabels[$section] = $text
    }
    
    [void] HandlePrimaryAction() {
        # Call custom handler first
        if ($this.OnPrimary -and $this.OnPrimary.GetType().Name -eq 'ScriptBlock') {
            & $this.OnPrimary
        }
        
        # Legacy support
        if ($this.OnCreate -and $this.OnCreate.GetType().Name -eq 'ScriptBlock') {
            & $this.OnCreate
        }
        
        # Default behavior - close dialog
        $this.CloseDialog()
    }
    
    [void] HandleSecondaryAction() {
        # Call custom handler first
        if ($this.OnSecondary -and $this.OnSecondary.GetType().Name -eq 'ScriptBlock') {
            & $this.OnSecondary
        }
        
        # Legacy support
        if ($this.OnCancel -and $this.OnCancel.GetType().Name -eq 'ScriptBlock') {
            & $this.OnCancel
        }
        
        # Default behavior - close dialog
        $this.CloseDialog()
    }
    
    [void] CloseDialog() {
        # Close this dialog - implementation depends on screen manager
        if ($global:ServiceContainer -and $global:ServiceContainer.HasService('ScreenManager')) {
            $screenManager = $global:ServiceContainer.GetService('ScreenManager')
            $screenManager.PopScreen()
        }
    }
    
    # Override OnBoundsChanged to position dialog in center
    [void] OnBoundsChanged() {
        # Center the dialog on screen
        $centerX = [Math]::Max(0, ([Console]::WindowWidth - $this.DialogWidth) / 2)
        $centerY = [Math]::Max(0, ([Console]::WindowHeight - $this.DialogHeight) / 2)
        
        # Store dialog bounds for rendering
        $this._dialogBounds = @{
            X = $centerX
            Y = $centerY
            Width = $this.DialogWidth
            Height = $this.DialogHeight
        }
        
        # Position the main layout within the dialog bounds
        if ($this._mainLayout) {
            # Content area (excluding border and title)
            $contentX = $centerX + 1  # +1 for left border
            $contentY = $centerY + 3  # +3 for top border and title
            $contentWidth = $this.DialogWidth - 2  # -2 for left/right borders
            $contentHeight = $this.DialogHeight - 4  # -4 for borders and title
            
            $this._mainLayout.SetBounds($contentX, $contentY, $contentWidth, $contentHeight)
        }
        
        # Call parent
        ([Container]$this).OnBoundsChanged()
    }
    
    # Override OnRender to draw dialog border and background
    [string] OnRender() {
        if (-not $this._dialogBounds -or $this._dialogBounds.Count -eq 0) {
            # Trigger bounds calculation
            $this.OnBoundsChanged()
        }
        
        $result = ""
        $x = $this._dialogBounds.X
        $y = $this._dialogBounds.Y
        $width = $this._dialogBounds.Width
        $height = $this._dialogBounds.Height
        
        # Get theme colors if available
        $borderColor = ""
        $bgColor = ""
        if ($this.Theme) {
            $borderColor = $this.Theme.GetColor('border.normal')
            $bgColor = $this.Theme.GetBgColor('surface.background')
        }
        
        # Draw dialog border using BorderStyle
        $result += [BorderStyle]::RenderBorder($x, $y, $width, $height, $this.BorderType, $borderColor)
        
        # Draw title bar
        $result += [VT]::MoveTo($x + 1, $y + 1)
        if ($bgColor) { $result += $bgColor }
        $titlePadding = [Math]::Max(0, ($width - 2 - $this.Title.Length) / 2)
        $rightPadding = [Math]::Max(0, ($width - 2) - $titlePadding - $this.Title.Length)
        $result += (" " * $titlePadding) + $this.Title + (" " * $rightPadding)
        $result += [VT]::Reset()
        
        # Clear content area
        for ($i = 2; $i -lt ($height - 1); $i++) {
            $result += [VT]::MoveTo($x + 1, $y + $i)
            if ($bgColor) { $result += $bgColor }
            $result += (" " * ($width - 2))
            $result += [VT]::Reset()
        }
        
        # Render child components (layout and controls)
        foreach ($child in $this.Children) {
            if ($child.Visible) {
                $result += $child.Render()
            }
        }
        
        return $result
    }
    
    # Dialog-specific input handling
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$keyInfo) {
        # Handle Escape as cancel
        if ($keyInfo.Key -eq [System.ConsoleKey]::Escape) {
            $this.HandleSecondaryAction()
            return $true
        }
        
        # Handle Enter as OK (only if no focused control handles it)
        if ($keyInfo.Key -eq [System.ConsoleKey]::Enter) {
            $this.HandlePrimaryAction()
            return $true
        }
        
        return $false
    }
}