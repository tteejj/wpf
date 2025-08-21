using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;

namespace PraxisWpf.Controls
{
    public partial class HelpOverlay : UserControl
    {
        public event EventHandler? CloseRequested;

        public static readonly DependencyProperty HelpTextProperty =
            DependencyProperty.Register(nameof(HelpText), typeof(string), typeof(HelpOverlay));

        public string HelpText
        {
            get => (string)GetValue(HelpTextProperty);
            set => SetValue(HelpTextProperty, value);
        }

        public HelpOverlay()
        {
            InitializeComponent();
            DataContext = this;
            
            // Auto-focus when loaded
            Loaded += (s, e) => Focus();
        }

        private void HelpOverlay_KeyDown(object sender, KeyEventArgs e)
        {
            // Any key closes the help overlay
            CloseRequested?.Invoke(this, EventArgs.Empty);
            e.Handled = true;
        }

        protected override void OnMouseDown(MouseButtonEventArgs e)
        {
            // Click anywhere to close
            CloseRequested?.Invoke(this, EventArgs.Empty);
            e.Handled = true;
            base.OnMouseDown(e);
        }
    }
}