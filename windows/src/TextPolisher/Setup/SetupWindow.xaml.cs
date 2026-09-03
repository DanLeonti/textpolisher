using System.Windows;

namespace TextPolisher.Setup;

public partial class SetupWindow : Window
{
    public SetupWindow()
    {
        InitializeComponent();
    }

    public void SetStatus(string status)
    {
        StatusText.Text = status;
    }

    public void SetDetail(string detail)
    {
        DetailText.Text = detail;
    }

    /// <summary>Sets progress 0-100, or null for an indeterminate bar.</summary>
    public void SetProgress(double? percent)
    {
        if (percent is null)
        {
            Progress.IsIndeterminate = true;
        }
        else
        {
            Progress.IsIndeterminate = false;
            Progress.Value = Math.Clamp(percent.Value, 0, 100);
        }
    }
}
