#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlContext>
#include <QRegularExpression>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QScreen>
#include <QSGRendererInterface>
#include <QTimer>
#include <QUrl>

// Small file read with a size cap; empty on any error.
static QByteArray readSmall(const QString &path, qint64 cap) {
  QFile f(path);
  if (!f.open(QIODevice::ReadOnly))
    return {};
  return f.read(cap);
}

// Matrix Rain wallpaper settings (letter size, speed, density, colour), so
// the screensaver matches the rain. MATRIX_RAIN_STATE overrides the path.
static QVariantMap rainState() {
  QString path = qEnvironmentVariable("MATRIX_RAIN_STATE");
  if (path.isEmpty())
    path = QDir::homePath() + QStringLiteral("/.local/state/ertiv.matrix-rain/state.json");
  const QJsonDocument doc = QJsonDocument::fromJson(readSmall(path, 65536));
  return doc.isObject() ? doc.object().toVariantMap() : QVariantMap();
}

// Current Omarchy theme accent, for the rain's "theme" colour.
static QString themeAccent() {
  const QString text = QString::fromUtf8(readSmall(
      QDir::homePath() + QStringLiteral("/.local/state/omarchy/current/theme/colors.toml"), 65536));
  const auto m = QRegularExpression(QStringLiteral("^accent\\s*=\\s*\"(#[0-9A-Fa-f]{6})\""),
                                    QRegularExpression::MultilineOption).match(text);
  return m.hasMatch() ? m.captured(1) : QStringLiteral("#3CBF5C");
}

int main(int argc, char **argv) {
  bool windowed = false;
  QString grabPath;
  for (int i = 1; i < argc; ++i) {
    if (qstrcmp(argv[i], "--windowed") == 0)
      windowed = true;
    if (qstrcmp(argv[i], "--grab") == 0 && i + 1 < argc)
      grabPath = QString::fromLocal8Bit(argv[++i]);
  }

  qputenv("QSG_RHI_BACKEND", "opengl");
  QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);

  if (!windowed)
    QGuiApplication::setDesktopFileName(QStringLiteral("org.omarchy.screensaver"));

  QGuiApplication app(argc, argv);
  app.setOrganizationName(QStringLiteral("omarchy"));
  if (windowed) {
    app.setApplicationName(QStringLiteral("ertiv-matrix-preview"));
  } else {
    app.setApplicationName(QStringLiteral("org.omarchy.screensaver"));
    app.setDesktopFileName(QStringLiteral("org.omarchy.screensaver"));
  }

  if (argc < 2)
    return 2;

  QQmlApplicationEngine engine;
  engine.rootContext()->setContextProperty(QStringLiteral("rainState"), rainState());
  engine.rootContext()->setContextProperty(QStringLiteral("themeAccent"), themeAccent());
  engine.load(QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1])));
  if (engine.rootObjects().isEmpty()) {
    fprintf(stderr, "screensaver: failed to load %s\n", argv[1]);
    return 2;
  }

  auto *win = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());
  if (!win) {
    fprintf(stderr, "screensaver: root is %s\n",
            engine.rootObjects().constFirst()->metaObject()->className());
    return 2;
  }

  if (!windowed) {
    if (QScreen *scr = win->screen() ? win->screen() : QGuiApplication::primaryScreen()) {
      win->setScreen(scr);
      win->setGeometry(scr->geometry());
    }
    win->showFullScreen();
  }

  if (!grabPath.isEmpty()) {
    QTimer::singleShot(1800, win, [win, grabPath]() {
      const QImage img = win->grabWindow();
      fprintf(stderr, "screensaver grab %dx%d null=%d to %s\n", img.width(),
              img.height(), int(img.isNull()), qPrintable(grabPath));
      if (!img.save(grabPath))
        fprintf(stderr, "screensaver grab save failed\n");
    });
  }

  return app.exec();
}
