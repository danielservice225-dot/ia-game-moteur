from __future__ import annotations
import csv, json, os, sys, threading, time
from pathlib import Path
from typing import Callable
import requests, uvicorn
from PySide6.QtCore import QObject, QRunnable, QThreadPool, Qt, Signal
from PySide6.QtWidgets import (QApplication, QFileDialog, QFrame, QHBoxLayout, QHeaderView, QLabel, QMainWindow, QMessageBox, QPushButton, QSpinBox, QDoubleSpinBox, QStackedWidget, QTableWidget, QTableWidgetItem, QTextEdit, QVBoxLayout, QWidget, QListWidget, QListWidgetItem, QProgressBar, QComboBox)

APP_NAME = "IA GAME ML Studio"
API_URL = "http://127.0.0.1:8765"

def prepare_runtime():
    root = Path(os.environ.get("LOCALAPPDATA", Path.home())) / APP_NAME if sys.platform == "win32" else Path.home()/".local/share/ia-game-ml-studio"
    artifacts = root / "artifacts"
    artifacts.mkdir(parents=True, exist_ok=True)
    os.environ["IA_GAME_ARTIFACT_DIR"] = str(artifacts)

class ApiServer:
    def __init__(self):
        self.server = None
        self.thread = None
    def start(self):
        from backend.main import app
        self.server = uvicorn.Server(uvicorn.Config(app, host="127.0.0.1", port=8765, log_level="warning", access_log=False))
        self.thread = threading.Thread(target=self.server.run, daemon=True, name="ia-game-api")
        self.thread.start()
        deadline = time.time()+25
        while time.time()<deadline:
            try:
                if requests.get(API_URL+"/health", timeout=1).ok: return
            except requests.RequestException:
                time.sleep(.25)
        raise RuntimeError("L'API ML locale n'a pas démarré.")
    def stop(self):
        if self.server: self.server.should_exit=True
        if self.thread: self.thread.join(timeout=5)

class Signals(QObject):
    done = Signal(object)
    error = Signal(str)

class Worker(QRunnable):
    def __init__(self, fn):
        super().__init__(); self.fn=fn; self.signals=Signals()
    def run(self):
        try: self.signals.done.emit(self.fn())
        except Exception as exc: self.signals.error.emit(str(exc))

STYLE = """
QMainWindow,QWidget{background:#11151c;color:#e8edf5;font-family:'Segoe UI';font-size:10pt}
QFrame#Side{background:#171d27;border-right:1px solid #293241}
QLabel#Brand{font-size:18pt;font-weight:700;color:white;padding:12px}
QLabel#Title{font-size:22pt;font-weight:700;color:white}
QLabel#Muted{color:#9aa8ba}
QPushButton{background:#263244;border:1px solid #35445a;border-radius:7px;padding:9px 14px;color:#f4f7fb}
QPushButton:hover{background:#34445c}
QPushButton#Primary{background:#2878d0;border-color:#398ce7;font-weight:600}
QListWidget{background:transparent;border:0}
QListWidget::item{padding:13px;border-radius:7px;color:#b9c5d5}
QListWidget::item:selected{background:#263d5c;color:white}
QComboBox,QSpinBox,QDoubleSpinBox,QTextEdit,QTableWidget{background:#171e29;border:1px solid #354154;border-radius:6px;padding:7px;color:#edf2f8}
QHeaderView::section{background:#222c3a;color:#dce5f1;padding:8px;border:0}
QProgressBar{background:#202a38;border:0;border-radius:4px;height:8px}
QProgressBar::chunk{background:#398ce7;border-radius:4px}
"""

class Studio(QMainWindow):
    def __init__(self, server):
        super().__init__(); self.server=server; self.pool=QThreadPool.globalInstance(); self.csv_path=None
        self.setWindowTitle(APP_NAME); self.resize(1220,800); self.setMinimumSize(980,650)
        root=QWidget(); h=QHBoxLayout(root); h.setContentsMargins(0,0,0,0); h.setSpacing(0)
        side=QFrame(); side.setObjectName("Side"); side.setFixedWidth(225); sv=QVBoxLayout(side)
        brand=QLabel("IA GAME\nML STUDIO"); brand.setObjectName("Brand"); sv.addWidget(brand)
        muted=QLabel("INDUSTRIAL MACHINE LEARNING"); muted.setObjectName("Muted"); sv.addWidget(muted)
        self.nav=QListWidget()
        for name in ["Vue générale","Datasets CSV","Entraînement ML","Historique","Prédictions"]: self.nav.addItem(QListWidgetItem(name))
        sv.addSpacing(20); sv.addWidget(self.nav,1)
        self.pages=QStackedWidget()
        for builder in [self.dashboard,self.datasets,self.training,self.history,self.predictions]: self.pages.addWidget(builder())
        self.nav.currentRowChanged.connect(self.pages.setCurrentIndex); self.nav.setCurrentRow(0)
        h.addWidget(side); h.addWidget(self.pages,1); self.setCentralWidget(root); self.statusBar().showMessage("Moteur ML local — port 8765")
        self.refresh()

    def shell(self,title,desc):
        page=QWidget(); v=QVBoxLayout(page); v.setContentsMargins(28,25,28,25); v.setSpacing(14)
        t=QLabel(title); t.setObjectName("Title"); v.addWidget(t)
        d=QLabel(desc); d.setObjectName("Muted"); v.addWidget(d)
        return page,v
    def card(self,title):
        f=QFrame(); f.setStyleSheet("QFrame{background:#1a2330;border:1px solid #2d3a4c;border-radius:10px}")
        v=QVBoxLayout(f); a=QLabel(title.upper()); a.setObjectName("Muted"); b=QLabel("…"); b.setStyleSheet("font-size:23pt;font-weight:700;border:0")
        v.addWidget(a); v.addWidget(b); f.value=b; return f
    def dashboard(self):
        p,v=self.shell("Vue générale","Entraînez des modèles sur vos données industrielles et utilisez-les dans la simulation Godot.")
        row=QHBoxLayout(); self.api_card=self.card("API locale"); self.model_card=self.card("Modèle actif"); self.count_card=self.card("Entraînements")
        for c in [self.api_card,self.model_card,self.count_card]: row.addWidget(c)
        v.addLayout(row)
        info=QTextEdit(); info.setReadOnly(True); info.setMaximumHeight(230)
        info.setHtml("<h2>Flux de travail</h2><p>1. Importez un CSV de données industrielles.</p><p>2. Contrôlez les colonnes et la qualité.</p><p>3. Choisissez la cible et lancez l'entraînement.</p><p>4. Évaluez le modèle sur un jeu de test séparé.</p><p>5. Le modèle enregistré est disponible pour les prédictions locales.</p><p><b>Attention :</b> la validité des résultats dépend de la qualité et de la provenance des données.</p>")
        v.addWidget(info); b=QPushButton("Actualiser"); b.clicked.connect(self.refresh); v.addWidget(b,alignment=Qt.AlignmentFlag.AlignLeft); v.addStretch()
        return p
    def datasets(self):
        p,v=self.shell("Datasets CSV","Importez un dataset local, inspectez son aperçu et son rapport de nettoyage.")
        row=QHBoxLayout(); choose=QPushButton("Choisir un fichier CSV"); choose.setObjectName("Primary"); choose.clicked.connect(self.choose_csv)
        preview=QPushButton("Analyser le dataset"); preview.clicked.connect(self.preview_csv)
        self.file_label=QLabel("Aucun fichier sélectionné"); self.file_label.setObjectName("Muted")
        row.addWidget(choose); row.addWidget(preview); row.addWidget(self.file_label,1); v.addLayout(row)
        self.dataset_summary=QLabel("Sélectionnez un fichier CSV."); self.dataset_summary.setObjectName("Muted"); v.addWidget(self.dataset_summary)
        self.table=QTableWidget(); self.table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.ResizeToContents); v.addWidget(self.table,1)
        self.clean_report=QTextEdit(); self.clean_report.setReadOnly(True); self.clean_report.setMaximumHeight(140); v.addWidget(self.clean_report)
        return p
    def training(self):
        p,v=self.shell("Entraînement ML","Le moteur actuel utilise un Random Forest de classification ou de régression.")
        panel=QFrame(); panel.setStyleSheet("QFrame{background:#1a2330;border:1px solid #2d3a4c;border-radius:10px}"); f=QVBoxLayout(panel)
        self.train_file=QLabel("Aucun CSV importé"); self.train_file.setObjectName("Muted"); f.addWidget(self.train_file)
        f.addWidget(QLabel("Variable cible")); self.target=QComboBox(); f.addWidget(self.target)
        row=QHBoxLayout(); row.addWidget(QLabel("Taille test")); self.test_size=QDoubleSpinBox(); self.test_size.setRange(.1,.5); self.test_size.setSingleStep(.05); self.test_size.setValue(.2); row.addWidget(self.test_size)
        row.addWidget(QLabel("Random state")); self.seed=QSpinBox(); self.seed.setRange(0,999999); self.seed.setValue(42); row.addWidget(self.seed); row.addStretch(); f.addLayout(row)
        self.train_btn=QPushButton("Lancer l'entraînement réel"); self.train_btn.setObjectName("Primary"); self.train_btn.clicked.connect(self.train); f.addWidget(self.train_btn)
        v.addWidget(panel); self.progress=QProgressBar(); self.progress.setRange(0,0); self.progress.hide(); v.addWidget(self.progress)
        self.train_output=QTextEdit(); self.train_output.setReadOnly(True); self.train_output.setPlaceholderText("Les métriques et mesures de ressources apparaîtront ici."); v.addWidget(self.train_output,1)
        return p
    def history(self):
        p,v=self.shell("Historique","Rapports enregistrés par le moteur ML.")
        b=QPushButton("Actualiser l'historique"); b.clicked.connect(self.load_history); v.addWidget(b,alignment=Qt.AlignmentFlag.AlignLeft)
        self.hist_table=QTableWidget(0,5); self.hist_table.setHorizontalHeaderLabels(["Date","Dataset","Cible","Tâche","Durée (s)"]); self.hist_table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch); v.addWidget(self.hist_table,1)
        return p
    def predictions(self):
        p,v=self.shell("Prédictions","Envoyez des mesures de capteurs au modèle enregistré.")
        v.addWidget(QLabel("Mesures au format JSON (liste d'enregistrements)"))
        self.pred_input=QTextEdit(); self.pred_input.setPlainText('[\n  {"temperature_c":75.0,"vibration_mm_s":2.4,"pressure_bar":5.1}\n]'); v.addWidget(self.pred_input,1)
        b=QPushButton("Exécuter la prédiction"); b.setObjectName("Primary"); b.clicked.connect(self.predict); v.addWidget(b,alignment=Qt.AlignmentFlag.AlignLeft)
        self.pred_output=QTextEdit(); self.pred_output.setReadOnly(True); v.addWidget(self.pred_output,1)
        return p
    def work(self,fn,success,error=None):
        w=Worker(fn); w.signals.done.connect(success); w.signals.error.connect(error or self.error); self.pool.start(w)
    def error(self,msg): QMessageBox.critical(self,APP_NAME,msg)
    def get(self,path):
        r=requests.get(API_URL+path,timeout=30); r.raise_for_status(); return r.json()
    def refresh(self):
        def task(): return self.get("/health"),self.get("/models/history")
        def done(pair):
            health,history=pair; self.api_card.value.setText("En ligne" if health.get("status")=="ok" else "Erreur")
            self.model_card.value.setText("Disponible" if health.get("model_available") else "Absent")
            self.count_card.value.setText(str(history.get("count",0)))
        self.work(task,done)
    def choose_csv(self):
        path,_=QFileDialog.getOpenFileName(self,"Sélectionner un dataset industriel","","CSV (*.csv)")
        if not path:return
        self.csv_path=Path(path)
        try:
            with self.csv_path.open("r",encoding="utf-8-sig",newline="") as f: columns=next(csv.reader(f))
        except Exception as exc: self.error(f"Lecture de l'en-tête impossible : {exc}"); return
        self.file_label.setText(self.csv_path.name); self.train_file.setText(str(self.csv_path))
        self.target.clear(); self.target.addItems(columns)
        self.dataset_summary.setText(f"{len(columns)} colonnes détectées.")
    def preview_csv(self):
        if not self.csv_path: self.error("Choisissez d'abord un fichier CSV."); return
        path=self.csv_path
        def task():
            with path.open("rb") as f: r=requests.post(API_URL+"/datasets/preview",files={"file":(path.name,f,"text/csv")},timeout=180)
            r.raise_for_status(); return r.json()
        def done(data):
            rows,cols=data.get("preview",[]),data.get("columns",[])
            self.table.clear(); self.table.setRowCount(len(rows)); self.table.setColumnCount(len(cols)); self.table.setHorizontalHeaderLabels(cols)
            for i,row in enumerate(rows):
                for j,col in enumerate(cols): self.table.setItem(i,j,QTableWidgetItem(str(row.get(col,""))))
            self.dataset_summary.setText(f"{data['rows_before']} lignes initiales → {data['rows_after']} après nettoyage • {len(cols)} colonnes")
            self.clean_report.setPlainText(json.dumps(data.get("report",{}),ensure_ascii=False,indent=2))
        self.work(task,done)
    def train(self):
        if not self.csv_path: self.error("Importez un dataset CSV avant l'entraînement."); return
        target=self.target.currentText()
        if not target:self.error("Sélectionnez une variable cible.");return
        path=self.csv_path; self.train_btn.setEnabled(False); self.progress.show(); self.train_output.setPlainText("Entraînement en cours…")
        def task():
            with path.open("rb") as f:
                r=requests.post(API_URL+"/models/train",params={"target":target,"test_size":self.test_size.value(),"random_state":self.seed.value()},files={"file":(path.name,f,"text/csv")},timeout=3600)
            r.raise_for_status(); return r.json()
        def done(report):
            self.progress.hide(); self.train_btn.setEnabled(True); self.train_output.setPlainText(json.dumps(report,ensure_ascii=False,indent=2)); self.statusBar().showMessage("Modèle entraîné et sauvegardé localement",10000); self.refresh()
        def fail(msg): self.progress.hide(); self.train_btn.setEnabled(True); self.error(msg)
        self.work(task,done,fail)
    def load_history(self):
        def done(data):
            items=data.get("items",[]); self.hist_table.setRowCount(len(items))
            for i,item in enumerate(items):
                vals=[item.get("created_at",""),item.get("source_filename",""),item.get("target",""),item.get("task",""),str(item.get("training_seconds",""))]
                for j,val in enumerate(vals): self.hist_table.setItem(i,j,QTableWidgetItem(val))
        self.work(lambda:self.get("/models/history"),done)
    def predict(self):
        try:
            rows=json.loads(self.pred_input.toPlainText())
            if not isinstance(rows,list) or not rows: raise ValueError("Le JSON doit être une liste non vide.")
        except (json.JSONDecodeError,ValueError) as exc:self.error(str(exc));return
        def task():
            r=requests.post(API_URL+"/models/predict",json={"rows":rows},timeout=120);r.raise_for_status();return r.json()
        self.work(task,lambda result:self.pred_output.setPlainText(json.dumps(result,ensure_ascii=False,indent=2)))
    def closeEvent(self,event):
        self.server.stop(); event.accept()

def main():
    prepare_runtime()
    app=QApplication(sys.argv); app.setApplicationName(APP_NAME); app.setStyleSheet(STYLE)
    server=ApiServer()
    try: server.start()
    except Exception as exc: QMessageBox.critical(None,APP_NAME,f"Impossible de démarrer le moteur ML local :\n{exc}"); return 1
    window=Studio(server); window.show(); return app.exec()

if __name__=="__main__": raise SystemExit(main())
