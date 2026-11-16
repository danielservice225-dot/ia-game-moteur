from __future__ import annotations

import json
import sys
import traceback
import uuid
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
from PySide6.QtCore import QObject, QThread, Qt, QStandardPaths, Signal
from PySide6.QtGui import QAction, QFont
from PySide6.QtWidgets import (
    QApplication, QCheckBox, QComboBox, QFileDialog, QFrame, QGridLayout,
    QHBoxLayout, QLabel, QMainWindow, QMessageBox, QProgressBar, QPushButton,
    QScrollArea, QSpinBox, QDoubleSpinBox, QSplitter, QTableWidget,
    QTableWidgetItem, QVBoxLayout, QWidget, QListWidget, QListWidgetItem,
)

from ml_engine.pipeline import clean_dataframe, train_model

APP_NAME = "IA GAME Trainer"


def app_data_dir() -> Path:
    root = Path(QStandardPaths.writableLocation(QStandardPaths.StandardLocation.AppDataLocation))
    root.mkdir(parents=True, exist_ok=True)
    (root / "models").mkdir(exist_ok=True)
    (root / "reports").mkdir(exist_ok=True)
    return root


class TrainingWorker(QObject):
    finished = Signal(dict)
    failed = Signal(str)

    def __init__(self, frame: pd.DataFrame, target: str, excluded: list[str],
                 test_size: float, random_state: int, model_path: Path):
        super().__init__()
        self.frame = frame.copy()
        self.target = target
        self.excluded = excluded
        self.test_size = test_size
        self.random_state = random_state
        self.model_path = model_path

    def run(self):
        try:
            training_frame = self.frame.drop(columns=self.excluded, errors="ignore")
            report = train_model(
                training_frame, self.target, self.model_path,
                test_size=self.test_size, random_state=self.random_state,
            )
            report_id = uuid.uuid4().hex
            report.update({
                "report_id": report_id,
                "created_at": datetime.now(timezone.utc).isoformat(),
                "source": "IA GAME Trainer desktop",
                "excluded_columns": self.excluded,
                "model_file": str(self.model_path),
            })
            report_path = app_data_dir() / "reports" / f"{report_id}.json"
            report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
            history_path = app_data_dir() / "reports" / "history.json"
            try:
                history = json.loads(history_path.read_text(encoding="utf-8"))
                if not isinstance(history, list):
                    history = []
            except (OSError, json.JSONDecodeError):
                history = []
            history.insert(0, {
                "report_id": report_id,
                "created_at": report["created_at"],
                "target": self.target,
                "task": report["task"],
                "metrics": report["metrics"],
                "training_seconds": report["training_seconds"],
                "report_path": str(report_path),
            })
            history_path.write_text(json.dumps(history[:100], ensure_ascii=False, indent=2), encoding="utf-8")
            report["report_path"] = str(report_path)
            self.finished.emit(report)
        except Exception:
            self.failed.emit(traceback.format_exc())


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle(APP_NAME)
        self.resize(1440, 900)
        self.setMinimumSize(1100, 720)
        self.frame: pd.DataFrame | None = None
        self.csv_path: Path | None = None
        self.last_report: dict | None = None
        self.worker_thread: QThread | None = None
        self.worker: TrainingWorker | None = None
        self.model_path = app_data_dir() / "models" / "model.joblib"
        self._build_ui()
        self._apply_style()
        self._load_history()

    def _build_ui(self):
        root = QWidget()
        self.setCentralWidget(root)
        layout = QHBoxLayout(root)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        sidebar = QFrame()
        sidebar.setObjectName("sidebar")
        sidebar.setFixedWidth(238)
        side = QVBoxLayout(sidebar)
        side.setContentsMargins(22, 26, 18, 22)
        brand = QLabel("IA GAME")
        brand.setObjectName("brand")
        side.addWidget(brand)
        subtitle = QLabel("MACHINE LEARNING STUDIO")
        subtitle.setObjectName("brandSub")
        side.addWidget(subtitle)
        side.addSpacing(36)
        for label in ("Vue d'ensemble", "Données", "Entraînement", "Rapports"):
            item = QLabel("  " + label)
            item.setObjectName("navItem")
            side.addWidget(item)
        side.addStretch()
        version = QLabel("DESKTOP EDITION  ·  1.0")
        version.setObjectName("muted")
        side.addWidget(version)
        layout.addWidget(sidebar)

        content = QWidget()
        content_layout = QVBoxLayout(content)
        content_layout.setContentsMargins(34, 28, 34, 28)
        content_layout.setSpacing(18)
        layout.addWidget(content, 1)

        header = QHBoxLayout()
        heading = QVBoxLayout()
        title = QLabel("Atelier d'entraînement")
        title.setObjectName("pageTitle")
        heading.addWidget(title)
        self.subtitle_label = QLabel("Importez un jeu de données pour entraîner un modèle sur votre ordinateur.")
        self.subtitle_label.setObjectName("muted")
        heading.addWidget(self.subtitle_label)
        header.addLayout(heading)
        header.addStretch()
        self.status_badge = QLabel("●  En attente")
        self.status_badge.setObjectName("status")
        header.addWidget(self.status_badge)
        content_layout.addLayout(header)

        actions = QHBoxLayout()
        self.file_label = QLabel("Aucun fichier CSV sélectionné")
        self.file_label.setObjectName("fileLabel")
        actions.addWidget(self.file_label, 1)
        self.open_button = QPushButton("Importer un CSV")
        self.open_button.setObjectName("primary")
        self.open_button.clicked.connect(self._choose_csv)
        actions.addWidget(self.open_button)
        content_layout.addLayout(actions)

        cards = QHBoxLayout()
        self.rows_card, self.columns_card, self.missing_card = self._metric_cards()
        for card in (self.rows_card, self.columns_card, self.missing_card):
            cards.addWidget(card)
        content_layout.addLayout(cards)

        splitter = QSplitter(Qt.Orientation.Horizontal)
        left = QFrame()
        left.setObjectName("panel")
        left_layout = QVBoxLayout(left)
        left_layout.setContentsMargins(18, 16, 18, 16)
        left_title = QLabel("Aperçu des données")
        left_title.setObjectName("sectionTitle")
        left_layout.addWidget(left_title)
        self.preview_table = QTableWidget(0, 0)
        self.preview_table.setAlternatingRowColors(True)
        self.preview_table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        left_layout.addWidget(self.preview_table, 1)
        splitter.addWidget(left)

        right = QFrame()
        right.setObjectName("panel")
        right.setMinimumWidth(330)
        right_layout = QVBoxLayout(right)
        right_layout.setContentsMargins(18, 16, 18, 16)
        config_title = QLabel("Configuration du modèle")
        config_title.setObjectName("sectionTitle")
        right_layout.addWidget(config_title)
        right_layout.addWidget(QLabel("Variable cible"))
        self.target_combo = QComboBox()
        self.target_combo.currentTextChanged.connect(self._refresh_exclusions)
        right_layout.addWidget(self.target_combo)
        right_layout.addWidget(QLabel("Colonnes à exclure"))
        self.exclude_list = QListWidget()
        right_layout.addWidget(self.exclude_list, 1)
        params = QGridLayout()
        params.addWidget(QLabel("Part de test"), 0, 0)
        self.test_size = QDoubleSpinBox()
        self.test_size.setRange(0.10, 0.50)
        self.test_size.setSingleStep(0.05)
        self.test_size.setValue(0.20)
        self.test_size.setSuffix(" %")
        self.test_size.setToolTip("Fraction du dataset réservée au test, exprimée ici en proportion.")
        params.addWidget(self.test_size, 0, 1)
        params.addWidget(QLabel("Random state"), 1, 0)
        self.random_state = QSpinBox()
        self.random_state.setRange(0, 999999)
        self.random_state.setValue(42)
        params.addWidget(self.random_state, 1, 1)
        right_layout.addLayout(params)
        self.train_button = QPushButton("Lancer l'entraînement")
        self.train_button.setObjectName("primary")
        self.train_button.setEnabled(False)
        self.train_button.clicked.connect(self._start_training)
        right_layout.addWidget(self.train_button)
        self.progress = QProgressBar()
        self.progress.setRange(0, 0)
        self.progress.hide()
        right_layout.addWidget(self.progress)
        splitter.addWidget(right)
        splitter.setSizes([760, 390])
        content_layout.addWidget(splitter, 1)

        bottom = QHBoxLayout()
        self.result_label = QLabel("Résultats : aucun entraînement effectué.")
        self.result_label.setObjectName("result")
        bottom.addWidget(self.result_label, 1)
        self.export_model_button = QPushButton("Exporter le modèle")
        self.export_model_button.setEnabled(False)
        self.export_model_button.clicked.connect(self._export_model)
        bottom.addWidget(self.export_model_button)
        self.export_report_button = QPushButton("Exporter le rapport")
        self.export_report_button.setEnabled(False)
        self.export_report_button.clicked.connect(self._export_report)
        bottom.addWidget(self.export_report_button)
        content_layout.addLayout(bottom)

        self.history_label = QLabel("Historique : aucun entraînement enregistré.")
        self.history_label.setObjectName("muted")
        content_layout.addWidget(self.history_label)

        file_menu = self.menuBar().addMenu("Fichier")
        open_action = QAction("Importer un CSV…", self)
        open_action.triggered.connect(self._choose_csv)
        file_menu.addAction(open_action)
        export_action = QAction("Exporter le modèle…", self)
        export_action.triggered.connect(self._export_model)
        file_menu.addAction(export_action)

    def _metric_cards(self):
        cards = []
        for caption in ("LIGNES", "COLONNES", "VALEURS MANQUANTES"):
            card = QFrame()
            card.setObjectName("metricCard")
            box = QVBoxLayout(card)
            box.setContentsMargins(16, 12, 16, 12)
            label = QLabel(caption)
            label.setObjectName("metricCaption")
            value = QLabel("—")
            value.setObjectName("metricValue")
            box.addWidget(label)
            box.addWidget(value)
            card.value_label = value
            cards.append(card)
        return cards

    def _apply_style(self):
        self.setStyleSheet("""
            QMainWindow, QWidget { background: #10151e; color: #e8edf5; font-family: 'Segoe UI'; font-size: 10pt; }
            #sidebar { background: #0b1018; border-right: 1px solid #263142; }
            #brand { color: #f5f8fc; font-size: 25pt; font-weight: 800; letter-spacing: 2px; }
            #brandSub, #muted { color: #8492a6; font-size: 8pt; }
            #navItem { color: #b9c5d5; padding: 11px 8px; border-radius: 7px; }
            #pageTitle { font-size: 22pt; font-weight: 700; color: #f3f6fb; }
            #status { color: #70c7a2; background: #15352d; padding: 8px 13px; border-radius: 13px; }
            #fileLabel { color: #aebbd0; background: #171f2c; border: 1px dashed #35445a; border-radius: 8px; padding: 13px; }
            #metricCard, #panel { background: #171f2c; border: 1px solid #263448; border-radius: 10px; }
            #metricCaption { color: #8495ad; font-size: 8pt; font-weight: 600; }
            #metricValue { color: #f3f6fb; font-size: 21pt; font-weight: 700; }
            #sectionTitle { color: #f1f5fa; font-size: 12pt; font-weight: 700; padding-bottom: 5px; }
            #result { color: #b9c8dc; }
            QComboBox, QSpinBox, QDoubleSpinBox, QListWidget, QTableWidget {
                background: #0f1722; border: 1px solid #2a394e; border-radius: 6px; padding: 7px; color: #e8edf5;
                selection-background-color: #285d92;
            }
            QHeaderView::section { background: #202b3b; color: #cbd7e6; padding: 7px; border: 0; }
            QTableWidget { gridline-color: #263448; alternate-background-color: #141d29; }
            QPushButton { background: #263448; color: #e8edf5; border: 1px solid #3b4b62; border-radius: 7px; padding: 10px 15px; }
            QPushButton:hover { background: #34465e; }
            QPushButton:disabled { color: #66758a; background: #1a2432; }
            QPushButton#primary { background: #2878c7; border: 1px solid #398bd8; color: white; font-weight: 700; }
            QPushButton#primary:hover { background: #3489da; }
            QProgressBar { border: 1px solid #2a394e; border-radius: 4px; background: #0f1722; height: 8px; }
            QProgressBar::chunk { background: #3b91dc; }
            QMenuBar { background: #0b1018; color: #dce5f0; }
        """)

    def _choose_csv(self):
        path, _ = QFileDialog.getOpenFileName(self, "Importer un fichier CSV", "", "Fichiers CSV (*.csv)")
        if not path:
            return
        try:
            frame = pd.read_csv(path)
            if frame.empty or len(frame.columns) < 2:
                raise ValueError("Le fichier doit contenir des lignes et au moins deux colonnes.")
            cleaned, cleaning_report = clean_dataframe(frame)
            if len(cleaned.columns) < 2:
                raise ValueError("Le nettoyage a supprimé trop de colonnes.")
            self.frame = frame
            self.csv_path = Path(path)
            self.file_label.setText(self.csv_path.name)
            self.subtitle_label.setText(f"{len(frame):,} lignes · {len(frame.columns)} colonnes · {self.csv_path}")
            self.rows_card.value_label.setText(f"{len(frame):,}".replace(",", " "))
            self.columns_card.value_label.setText(str(len(frame.columns)))
            self.missing_card.value_label.setText(str(int(frame.isna().sum().sum())))
            self._show_preview(frame)
            self.target_combo.clear()
            self.target_combo.addItems([str(column) for column in frame.columns])
            if "Machine failure" in frame.columns:
                self.target_combo.setCurrentText("Machine failure")
            else:
                self.target_combo.setCurrentIndex(len(frame.columns) - 1)
            self._refresh_exclusions()
            self.train_button.setEnabled(True)
            self.status_badge.setText("●  Dataset chargé")
            self.result_label.setText(
                f"Contrôle initial : {int(frame.duplicated().sum())} doublons · "
                f"{cleaning_report['missing_values_total']} valeurs manquantes après nettoyage."
            )
        except Exception as exc:
            QMessageBox.critical(self, "Import CSV impossible", str(exc))

    def _show_preview(self, frame: pd.DataFrame):
        preview = frame.head(100)
        self.preview_table.clear()
        self.preview_table.setRowCount(len(preview))
        self.preview_table.setColumnCount(len(preview.columns))
        self.preview_table.setHorizontalHeaderLabels([str(column) for column in preview.columns])
        for row_index, (_, row) in enumerate(preview.iterrows()):
            for column_index, value in enumerate(row):
                text = "" if pd.isna(value) else str(value)
                self.preview_table.setItem(row_index, column_index, QTableWidgetItem(text))
        self.preview_table.resizeColumnsToContents()

    def _refresh_exclusions(self, _text=""):
        if self.frame is None:
            return
        target = self.target_combo.currentText()
        defaults = {"UDI", "Product ID"}
        if target == "Machine failure":
            defaults.update({"TWF", "HDF", "PWF", "OSF", "RNF"})
        self.exclude_list.clear()
        for column in self.frame.columns:
            if str(column) == target:
                continue
            item = QListWidgetItem(str(column))
            item.setFlags(item.flags() | Qt.ItemFlag.ItemIsUserCheckable)
            item.setCheckState(Qt.CheckState.Checked if str(column) in defaults else Qt.CheckState.Unchecked)
            self.exclude_list.addItem(item)

    def _start_training(self):
        if self.frame is None:
            return
        target = self.target_combo.currentText()
        excluded = [
            self.exclude_list.item(index).text()
            for index in range(self.exclude_list.count())
            if self.exclude_list.item(index).checkState() == Qt.CheckState.Checked
        ]
        if not target or len(self.frame.columns) - len(excluded) < 2:
            QMessageBox.warning(self, "Configuration invalide", "Conservez la cible et au moins une variable explicative.")
            return
        self.train_button.setEnabled(False)
        self.open_button.setEnabled(False)
        self.progress.show()
        self.status_badge.setText("●  Entraînement en cours")
        self.result_label.setText("Entraînement réel en cours sur les données importées…")
        self.worker_thread = QThread(self)
        self.worker = TrainingWorker(
            self.frame, target, excluded, self.test_size.value(),
            self.random_state.value(), self.model_path,
        )
        self.worker.moveToThread(self.worker_thread)
        self.worker_thread.started.connect(self.worker.run)
        self.worker.finished.connect(self._training_finished)
        self.worker.failed.connect(self._training_failed)
        self.worker.finished.connect(self.worker_thread.quit)
        self.worker.failed.connect(self.worker_thread.quit)
        self.worker_thread.finished.connect(self._training_cleanup)
        self.worker_thread.start()

    def _training_finished(self, report: dict):
        self.last_report = report
        metrics = report["metrics"]
        summary = "  ·  ".join(f"{key}: {value:.4f}" for key, value in metrics.items() if isinstance(value, (int, float)))
        self.result_label.setText(
            f"{report['task'].upper()} · {report['train_rows']} train / {report['test_rows']} test · "
            f"{report['training_seconds']:.2f} s  ·  {summary}"
        )
        self.status_badge.setText("●  Modèle entraîné")
        self.export_model_button.setEnabled(True)
        self.export_report_button.setEnabled(True)
        self._load_history()
        QMessageBox.information(self, "Entraînement terminé", "Le modèle et le rapport ont été enregistrés localement.")

    def _training_failed(self, details: str):
        self.status_badge.setText("●  Erreur")
        self.result_label.setText("L'entraînement a échoué. Consultez le message d'erreur.")
        QMessageBox.critical(self, "Échec de l'entraînement", details[-5000:])

    def _training_cleanup(self):
        self.progress.hide()
        self.train_button.setEnabled(self.frame is not None)
        self.open_button.setEnabled(True)
        self.worker = None
        self.worker_thread = None

    def _load_history(self):
        history_path = app_data_dir() / "reports" / "history.json"
        try:
            history = json.loads(history_path.read_text(encoding="utf-8"))
            self.history_label.setText("Historique récent : " + "  |  ".join(
                f"{item.get('target', '?')} · {item.get('created_at', '')[:16]} · {item.get('training_seconds', 0):.2f}s"
                for item in history[:5]
            ))
        except (OSError, json.JSONDecodeError):
            self.history_label.setText("Historique : aucun entraînement enregistré.")

    def _export_model(self):
        if not self.model_path.is_file():
            return
        path, _ = QFileDialog.getSaveFileName(self, "Exporter le modèle entraîné", "ia-game-model.joblib", "Modèle Joblib (*.joblib)")
        if path:
            Path(path).write_bytes(self.model_path.read_bytes())
            QMessageBox.information(self, "Export terminé", f"Modèle exporté :\n{path}")

    def _export_report(self):
        if not self.last_report:
            return
        path, _ = QFileDialog.getSaveFileName(self, "Exporter le rapport", "ia-game-training-report.json", "Rapport JSON (*.json)")
        if path:
            Path(path).write_text(json.dumps(self.last_report, ensure_ascii=False, indent=2), encoding="utf-8")
            QMessageBox.information(self, "Export terminé", f"Rapport exporté :\n{path}")


def main():
    app = QApplication(sys.argv)
    app.setApplicationName(APP_NAME)
    app.setOrganizationName("IA GAME")
    app.setFont(QFont("Segoe UI", 10))
    window = MainWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
