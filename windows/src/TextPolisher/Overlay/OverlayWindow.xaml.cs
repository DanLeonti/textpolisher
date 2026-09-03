using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using TextPolisher.Engine;

namespace TextPolisher.Overlay;

public partial class OverlayWindow : Window
{
    private readonly OverlayViewModel _viewModel;
    private readonly Dictionary<Tone, Button> _toneButtons = new();

    private static readonly Brush SelectedBrush = new SolidColorBrush(Color.FromRgb(0x5B, 0x54, 0xE8));
    private static readonly Brush SelectedForeground = Brushes.White;
    private static readonly Brush IdleBrush = new SolidColorBrush(Color.FromRgb(0xF0, 0xF0, 0xF3));
    private static readonly Brush IdleForeground = new SolidColorBrush(Color.FromRgb(0x33, 0x33, 0x33));

    public OverlayWindow(OverlayViewModel viewModel)
    {
        InitializeComponent();
        _viewModel = viewModel;
        DataContext = viewModel;

        BuildToneButtons();
        UpdateToneHighlight();

        _viewModel.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(OverlayViewModel.SelectedTone))
            {
                UpdateToneHighlight();
            }
        };

        _viewModel.Accepted += (_, _) => Close();
        _viewModel.Cancelled += (_, _) => Close();

        Loaded += OnLoaded;
    }

    private void BuildToneButtons()
    {
        foreach (var tone in _viewModel.Tones)
        {
            var button = new Button
            {
                Content = tone.Title(),
                Style = (Style)FindResource("ToneButton"),
                Tag = tone,
            };
            button.Click += (_, _) => _viewModel.SelectTone((Tone)button.Tag);
            _toneButtons[tone] = button;
            TonePanel.Children.Add(button);
        }
    }

    private void UpdateToneHighlight()
    {
        foreach (var (tone, button) in _toneButtons)
        {
            bool selected = tone == _viewModel.SelectedTone;
            button.Background = selected ? SelectedBrush : IdleBrush;
            button.Foreground = selected ? SelectedForeground : IdleForeground;
        }
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        PositionNearCursor();
        _viewModel.Start();
    }

    private void PositionNearCursor()
    {
        var cursor = System.Windows.Forms.Cursor.Position;
        var screen = System.Windows.Forms.Screen.FromPoint(cursor);
        double dpi = VisualTreeHelper.GetDpi(this).DpiScaleX;
        if (dpi <= 0) dpi = 1;

        // Convert device pixels to WPF DIPs.
        double cursorX = cursor.X / dpi;
        double cursorY = cursor.Y / dpi;
        double workLeft = screen.WorkingArea.Left / dpi;
        double workTop = screen.WorkingArea.Top / dpi;
        double workRight = screen.WorkingArea.Right / dpi;
        double workBottom = screen.WorkingArea.Bottom / dpi;

        double left = cursorX + 12;
        double top = cursorY + 16;

        if (left + ActualWidth > workRight) left = workRight - ActualWidth - 8;
        if (top + ActualHeight > workBottom) top = workBottom - ActualHeight - 8;
        if (left < workLeft) left = workLeft + 8;
        if (top < workTop) top = workTop + 8;

        Left = left;
        Top = top;
    }

    private void OnReplace(object sender, RoutedEventArgs e) => _viewModel.Accept();

    private void OnRegenerate(object sender, RoutedEventArgs e) => _viewModel.Regenerate();

    private void OnCancel(object sender, RoutedEventArgs e) => _viewModel.Cancel();
}
