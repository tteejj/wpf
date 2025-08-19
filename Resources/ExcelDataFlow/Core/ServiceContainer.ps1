# ServiceContainer.ps1 - Simple dependency injection for ExcelDataFlow
# Standalone implementation without complex features

class ServiceContainer {
    hidden [hashtable]$_services = @{}
    
    ServiceContainer() {
        $this._services = @{}
    }
    
    # Register a service instance
    [void] RegisterInstance([string]$name, [object]$instance) {
        $this._services[$name] = $instance
    }
    
    # Get a service by name
    [object] GetService([string]$name) {
        if ($this._services.ContainsKey($name)) {
            return $this._services[$name]
        }
        return $null
    }
    
    # Check if service exists
    [bool] HasService([string]$name) {
        return $this._services.ContainsKey($name)
    }
    
    # Remove a service
    [void] UnregisterService([string]$name) {
        if ($this._services.ContainsKey($name)) {
            $this._services.Remove($name)
        }
    }
}