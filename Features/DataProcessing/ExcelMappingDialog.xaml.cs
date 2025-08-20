using System.Windows;
using PraxisWpf.Services;

namespace PraxisWpf.Features.DataProcessing
{
    public partial class ExcelMappingDialog : Window
    {
        public ExcelMappingDialog()
        {
            Logger.TraceEnter();
            InitializeComponent();
            DataContext = new ExcelMappingViewModel();
            Logger.TraceExit();
        }

        public ExcelMappingDialog(ExcelMappingViewModel viewModel)
        {
            Logger.TraceEnter();
            InitializeComponent();
            DataContext = viewModel;
            Logger.TraceExit();
        }

        private void CloseButton_Click(object sender, RoutedEventArgs e)
        {
            Logger.Trace("ExcelMappingDialog", "Close button clicked");
            Close();
        }
    }
}