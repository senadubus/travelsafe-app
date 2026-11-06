import os
import time
import json
import warnings

import pandas as pd
import numpy as np
import psycopg2
import joblib

from dotenv import load_dotenv

load_dotenv()

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from sklearn.model_selection import TimeSeriesSplit
from sklearn.metrics import (
    mean_absolute_error,
    mean_squared_error,
    r2_score,
    confusion_matrix,
    classification_report
)

from xgboost import XGBRegressor


# =====================================================
# GENERAL SETTINGS
# =====================================================

warnings.filterwarnings("ignore", category=UserWarning, module="pandas")

START_TIME = time.time()

OUTPUT_DIR = "image/xgboost_analysis"
CSV_DIR = os.path.join(OUTPUT_DIR, "csv")
MODEL_DIR = "models"

os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(CSV_DIR, exist_ok=True)
os.makedirs(MODEL_DIR, exist_ok=True)


def save_plot(filename):
    """
    Grafikleri hem PNG hem JPG olarak kaydeder.
    LaTeX tarafında hangisini istersen onu kullanırsın.
    """
    png_path = os.path.join(OUTPUT_DIR, f"{filename}.png")
    jpg_path = os.path.join(OUTPUT_DIR, f"{filename}.jpg")

    plt.tight_layout()
    plt.savefig(png_path, dpi=300, bbox_inches="tight")
    plt.savefig(jpg_path, dpi=300, bbox_inches="tight")
    plt.close()

    print(f"Saved -> {png_path}")
    print(f"Saved -> {jpg_path}")


def safe_numeric(series):
    return pd.to_numeric(series, errors="coerce")


# =====================================================
# DATABASE CONNECTION
# =====================================================

conn = psycopg2.connect(
    host=os.getenv("DB_HOST", "localhost"),
    port=os.getenv("DB_PORT", "5432"),
    database=os.getenv("DB_NAME", "travelsafe"),
    user=os.getenv("DB_USER", "postgres"),
    password=os.getenv("DB_PASSWORD", "")
)

query = """
SELECT *
FROM crime_grid_weekly
WHERE week_start <= DATE '2025-07-28'
AND grid_id IN (
    SELECT grid_id
    FROM crime_grid_weekly
    WHERE week_start <= DATE '2025-07-28'
    GROUP BY grid_id
    HAVING SUM(total_count) >= 10
)
ORDER BY week_start, grid_id
"""

df = pd.read_sql(query, conn)
conn.close()

print("\n=================================")
print("DATA LOADED")
print("=================================")
print("Rows:", len(df))
print("Cols:", len(df.columns))

if "week_start" in df.columns:
    df["week_start"] = pd.to_datetime(df["week_start"])

# Dataset summary kaydı
dataset_summary = {
    "rows": int(len(df)),
    "columns": int(len(df.columns)),
    "column_names": list(df.columns)
}

with open(os.path.join(CSV_DIR, "dataset_summary.json"), "w", encoding="utf-8") as f:
    json.dump(dataset_summary, f, ensure_ascii=False, indent=4)


# =====================================================
# TARGET & STATIONARITY
# =====================================================

TARGET = "total_count"

required_cols = [TARGET, "rolling_4w_mean"]
missing_required = [c for c in required_cols if c not in df.columns]

if missing_required:
    raise ValueError(f"Eksik zorunlu kolonlar var: {missing_required}")

df[TARGET] = safe_numeric(df[TARGET]).fillna(0)
df["rolling_4w_mean"] = safe_numeric(df["rolling_4w_mean"]).fillna(0)

df["target_log"] = np.log1p(df[TARGET])
df["rolling_4w_mean_log"] = np.log1p(df["rolling_4w_mean"])
df["target_diff"] = df["target_log"] - df["rolling_4w_mean_log"]

# Target istatistikleri
target_stats = df[[TARGET, "target_log", "target_diff", "rolling_4w_mean"]].describe()
target_stats.to_csv(os.path.join(CSV_DIR, "target_statistics.csv"))


# =====================================================
# FEATURE LIST
# =====================================================

candidate_features = [
    # Temporal
    "year", "month", "weekofyear",
    "month_sin", "month_cos", "week_sin", "week_cos",

    # Spatial
    "grid_lat", "grid_lon", "dist_to_center_km",

    # Lag
    "lag_1w", "lag_2w", "lag_3w", "lag_4w",
    "lag_8w", "lag_12w", "lag_26w", "lag_52w",

    # Rolling Mean
    "rolling_4w_mean", "rolling_8w_mean", "rolling_12w_mean",

    # Rolling Std
    "rolling_4w_std", "rolling_8w_std", "rolling_12w_std",

    # Rolling Max
    "rolling_4w_max", "rolling_12w_max",

    # Trend & Neighbors
    "momentum_4_12",
    "neighbor_prev_1w",
    "neighbor_prev_4w_mean",
    "neighbor_momentum",

    # Zero Inflation & Density
    "zero_ratio_12w",
    "weeks_since_last_crime",
    "historical_density_rank"
]

features = [f for f in candidate_features if f in df.columns]
missing_features = [f for f in candidate_features if f not in df.columns]

print("\n=================================")
print("FEATURE INFO")
print("=================================")
print("Cleaned Feature Count:", len(features))
print("Missing Features:", missing_features)

pd.DataFrame({
    "used_features": features
}).to_csv(os.path.join(CSV_DIR, "used_features.csv"), index=False)

pd.DataFrame({
    "missing_features": missing_features
}).to_csv(os.path.join(CSV_DIR, "missing_features.csv"), index=False)


# =====================================================
# DATASET PREPARATION
# =====================================================

X = df[features].copy()

for col in X.columns:
    X[col] = safe_numeric(X[col])

missing_report = pd.DataFrame({
    "feature": X.columns,
    "missing_count_before_fill": X.isna().sum().values,
    "missing_ratio_before_fill": X.isna().mean().values
})

missing_report.to_csv(os.path.join(CSV_DIR, "missing_value_report.csv"), index=False)

X = X.fillna(0)

y_diff = df["target_diff"].fillna(0)

feature_stats = X.describe().T
feature_stats.to_csv(os.path.join(CSV_DIR, "feature_statistics.csv"))


# =====================================================
# BASIC DATA ANALYSIS PLOTS
# =====================================================

print("\n=================================")
print("CREATING DATA ANALYSIS PLOTS")
print("=================================")

# 1) Target distribution
plt.figure(figsize=(9, 5))
plt.hist(df[TARGET], bins=80)
plt.xlabel("Weekly Crime Count")
plt.ylabel("Frequency")
plt.title("Target Distribution: Weekly Crime Count")
save_plot("01_target_distribution_total_count")

# 2) Log target distribution
plt.figure(figsize=(9, 5))
plt.hist(df["target_log"], bins=80)
plt.xlabel("log1p(Weekly Crime Count)")
plt.ylabel("Frequency")
plt.title("Log-Transformed Target Distribution")
save_plot("02_target_distribution_log")

# 3) Stationary target distribution
plt.figure(figsize=(9, 5))
plt.hist(df["target_diff"], bins=80)
plt.xlabel("Target Difference")
plt.ylabel("Frequency")
plt.title("Stationary Target Distribution")
save_plot("03_target_distribution_stationary_diff")

# 4) Weekly total trend
if "week_start" in df.columns:
    weekly_total = df.groupby("week_start")[TARGET].sum().reset_index()

    weekly_total.to_csv(
        os.path.join(CSV_DIR, "weekly_total_crime_trend.csv"),
        index=False
    )

    plt.figure(figsize=(12, 5))
    plt.plot(weekly_total["week_start"], weekly_total[TARGET])
    plt.xlabel("Week")
    plt.ylabel("Total Crime Count")
    plt.title("Weekly Total Crime Trend")
    save_plot("04_weekly_total_crime_trend")

# 5) Monthly distribution
if "month" in df.columns:
    monthly_total = df.groupby("month")[TARGET].sum().reset_index()

    monthly_total.to_csv(
        os.path.join(CSV_DIR, "monthly_total_crime_distribution.csv"),
        index=False
    )

    plt.figure(figsize=(9, 5))
    plt.bar(monthly_total["month"], monthly_total[TARGET])
    plt.xlabel("Month")
    plt.ylabel("Total Crime Count")
    plt.title("Monthly Crime Distribution")
    plt.xticks(monthly_total["month"])
    save_plot("05_monthly_crime_distribution")

# 6) Yearly distribution
if "year" in df.columns:
    yearly_total = df.groupby("year")[TARGET].sum().reset_index()

    yearly_total.to_csv(
        os.path.join(CSV_DIR, "yearly_total_crime_distribution.csv"),
        index=False
    )

    plt.figure(figsize=(9, 5))
    plt.bar(yearly_total["year"].astype(str), yearly_total[TARGET])
    plt.xlabel("Year")
    plt.ylabel("Total Crime Count")
    plt.title("Yearly Crime Distribution")
    save_plot("06_yearly_crime_distribution")

# 7) Top 20 high crime grids
if "grid_id" in df.columns:
    top_grids = (
        df.groupby("grid_id")[TARGET]
        .sum()
        .sort_values(ascending=False)
        .head(20)
    )

    top_grids.to_csv(
        os.path.join(CSV_DIR, "top20_high_crime_grids.csv"),
        header=["total_count"]
    )

    plt.figure(figsize=(10, 6))
    plt.barh(top_grids.index.astype(str), top_grids.values)
    plt.gca().invert_yaxis()
    plt.xlabel("Total Crime Count")
    plt.ylabel("Grid ID")
    plt.title("Top 20 High Crime Grids")
    save_plot("07_top20_high_crime_grids")

# 8) Feature correlation heatmap
if len(features) >= 2:
    corr = X[features].corr()
    corr.to_csv(os.path.join(CSV_DIR, "feature_correlation_matrix.csv"))

    plt.figure(figsize=(12, 10))
    plt.imshow(corr, aspect="auto")
    plt.colorbar(label="Correlation")
    plt.xticks(range(len(corr.columns)), corr.columns, rotation=90)
    plt.yticks(range(len(corr.index)), corr.index)
    plt.title("Feature Correlation Heatmap")
    save_plot("08_feature_correlation_heatmap")


# =====================================================
# MODEL FACTORY
# =====================================================

def create_xgb_model():
    return XGBRegressor(
        objective="reg:squarederror",
        n_estimators=400,
        learning_rate=0.03,
        max_depth=5,
        min_child_weight=15,
        subsample=0.7,
        colsample_bytree=0.5,
        reg_alpha=1.0,
        reg_lambda=5.0,
        random_state=42,
        n_jobs=-1
    )


# =====================================================
# CROSS VALIDATION
# =====================================================

print("\n=================================")
print("STARTING TIME SERIES CROSS VALIDATION")
print("=================================")

tscv = TimeSeriesSplit(n_splits=5)

maes = []
rmses = []
r2s = []

metrics_records = []
prediction_records = []

for fold, (train_idx, test_idx) in enumerate(tscv.split(X)):
    fold_no = fold + 1

    print("\n======================")
    print(f"FOLD {fold_no}")
    print("======================")

    X_train, X_test = X.iloc[train_idx], X.iloc[test_idx]
    y_train_diff, y_test_diff = y_diff.iloc[train_idx], y_diff.iloc[test_idx]

    model = create_xgb_model()
    model.fit(X_train, y_train_diff)

    pred_diff = model.predict(X_test)

    rolling_log_test = np.log1p(
        df.iloc[test_idx]["rolling_4w_mean"].fillna(0).to_numpy()
    )

    pred_log = pred_diff + rolling_log_test
    real_log = y_test_diff.to_numpy() + rolling_log_test

    pred = np.expm1(pred_log)
    real = np.expm1(real_log)

    pred = np.clip(pred, 0, None)
    real = np.clip(real, 0, None)

    mae = mean_absolute_error(real, pred)
    rmse = np.sqrt(mean_squared_error(real, pred))
    r2 = r2_score(real, pred)

    maes.append(mae)
    rmses.append(rmse)
    r2s.append(r2)

    if "week_start" in df.columns:
        test_start_date = df.iloc[test_idx]["week_start"].min()
        test_end_date = df.iloc[test_idx]["week_start"].max()
    else:
        test_start_date = None
        test_end_date = None

    metrics_records.append({
        "fold": fold_no,
        "MAE": mae,
        "RMSE": rmse,
        "R2": r2,
        "train_size": len(train_idx),
        "test_size": len(test_idx),
        "test_start_date": test_start_date,
        "test_end_date": test_end_date
    })

    fold_pred_df = pd.DataFrame({
        "fold": fold_no,
        "row_index": test_idx,
        "real": real,
        "pred": pred
    })

    if "week_start" in df.columns:
        fold_pred_df["week_start"] = df.iloc[test_idx]["week_start"].values

    if "grid_id" in df.columns:
        fold_pred_df["grid_id"] = df.iloc[test_idx]["grid_id"].values

    fold_pred_df["residual"] = fold_pred_df["real"] - fold_pred_df["pred"]
    fold_pred_df["abs_error"] = np.abs(fold_pred_df["residual"])
    fold_pred_df["squared_error"] = fold_pred_df["residual"] ** 2

    prediction_records.append(fold_pred_df)

    print(f"MAE  : {mae:.4f}")
    print(f"RMSE : {rmse:.4f}")
    print(f"R2   : {r2:.4f}")


# =====================================================
# FINAL CV RESULTS
# =====================================================

metrics_df = pd.DataFrame(metrics_records)
pred_df = pd.concat(prediction_records, ignore_index=True)

metrics_df.to_csv(os.path.join(CSV_DIR, "xgb_cv_metrics.csv"), index=False)
pred_df.to_csv(os.path.join(CSV_DIR, "xgb_predictions_all_folds.csv"), index=False)

final_results = {
    "mean_MAE": float(np.mean(maes)),
    "mean_RMSE": float(np.mean(rmses)),
    "mean_R2": float(np.mean(r2s)),
    "std_MAE": float(np.std(maes)),
    "std_RMSE": float(np.std(rmses)),
    "std_R2": float(np.std(r2s))
}

with open(os.path.join(CSV_DIR, "xgb_final_cv_results.json"), "w", encoding="utf-8") as f:
    json.dump(final_results, f, ensure_ascii=False, indent=4)

print("\n=================================")
print("FINAL ROBUST RESULTS")
print("=================================")
print(f"Mean MAE  : {np.mean(maes):.4f}")
print(f"Mean RMSE : {np.mean(rmses):.4f}")
print(f"Mean R2   : {np.mean(r2s):.4f}")
print(f"Std MAE   : {np.std(maes):.4f}")
print(f"Std RMSE  : {np.std(rmses):.4f}")
print(f"Std R2    : {np.std(r2s):.4f}")


# =====================================================
# CV METRIC PLOTS
# =====================================================

print("\n=================================")
print("CREATING MODEL PERFORMANCE PLOTS")
print("=================================")

# 9) MAE by fold
plt.figure(figsize=(8, 5))
plt.bar(metrics_df["fold"], metrics_df["MAE"])
plt.xlabel("Fold")
plt.ylabel("MAE")
plt.title("XGBoost Cross-Validation MAE Scores")
plt.xticks(metrics_df["fold"])
save_plot("09_xgb_cv_mae_scores")

# 10) RMSE by fold
plt.figure(figsize=(8, 5))
plt.bar(metrics_df["fold"], metrics_df["RMSE"])
plt.xlabel("Fold")
plt.ylabel("RMSE")
plt.title("XGBoost Cross-Validation RMSE Scores")
plt.xticks(metrics_df["fold"])
save_plot("10_xgb_cv_rmse_scores")

# 11) R2 by fold
plt.figure(figsize=(8, 5))
plt.bar(metrics_df["fold"], metrics_df["R2"])
plt.xlabel("Fold")
plt.ylabel("R2")
plt.title("XGBoost Cross-Validation R2 Scores")
plt.xticks(metrics_df["fold"])
save_plot("11_xgb_cv_r2_scores")

# 12) Combined metrics
plt.figure(figsize=(9, 5))
x = np.arange(len(metrics_df["fold"]))
width = 0.25

plt.bar(x - width, metrics_df["MAE"], width, label="MAE")
plt.bar(x, metrics_df["RMSE"], width, label="RMSE")
plt.bar(x + width, metrics_df["R2"], width, label="R2")

plt.xlabel("Fold")
plt.ylabel("Metric Value")
plt.title("XGBoost Cross-Validation Metrics")
plt.xticks(x, metrics_df["fold"])
plt.legend()
save_plot("12_xgb_cv_metrics_combined")


# =====================================================
# PREDICTION ANALYSIS PLOTS
# =====================================================

# Büyük veri olduğu için scatter plotta örneklem alıyoruz
sample_df = pred_df.sample(
    n=min(50000, len(pred_df)),
    random_state=42
)

# 13) Actual vs Predicted scatter
plt.figure(figsize=(7, 7))
plt.scatter(sample_df["real"], sample_df["pred"], alpha=0.25, s=8)

max_val = np.percentile(
    np.concatenate([sample_df["real"].values, sample_df["pred"].values]),
    99
)

plt.plot([0, max_val], [0, max_val], linestyle="--")
plt.xlim(0, max_val)
plt.ylim(0, max_val)
plt.xlabel("Actual Crime Count")
plt.ylabel("Predicted Crime Count")
plt.title("XGBoost Actual vs Predicted")
save_plot("13_xgb_actual_vs_predicted")

# 14) Actual and predicted distribution
real_clip = np.percentile(pred_df["real"], 99)
pred_clip = np.percentile(pred_df["pred"], 99)

plt.figure(figsize=(9, 5))
plt.hist(pred_df["real"].clip(0, real_clip), bins=80, alpha=0.6, label="Actual")
plt.hist(pred_df["pred"].clip(0, pred_clip), bins=80, alpha=0.6, label="Predicted")
plt.xlabel("Crime Count")
plt.ylabel("Frequency")
plt.title("Actual and Predicted Crime Count Distribution")
plt.legend()
save_plot("14_actual_predicted_distribution")

# 15) Residual distribution
res_clip = np.percentile(np.abs(pred_df["residual"]), 99)

plt.figure(figsize=(9, 5))
plt.hist(pred_df["residual"].clip(-res_clip, res_clip), bins=80)
plt.xlabel("Residual / Error (Actual - Predicted)")
plt.ylabel("Frequency")
plt.title("XGBoost Residual Distribution")
save_plot("15_xgb_residual_distribution")

# 16) Absolute error distribution
abs_clip = np.percentile(pred_df["abs_error"], 99)

plt.figure(figsize=(9, 5))
plt.hist(pred_df["abs_error"].clip(0, abs_clip), bins=80)
plt.xlabel("Absolute Error")
plt.ylabel("Frequency")
plt.title("XGBoost Absolute Error Distribution")
save_plot("16_xgb_absolute_error_distribution")

# 17) Residuals vs predicted values
plt.figure(figsize=(9, 5))
plt.scatter(sample_df["pred"], sample_df["residual"], alpha=0.25, s=8)
plt.axhline(0, linestyle="--")
plt.xlabel("Predicted Crime Count")
plt.ylabel("Residual / Error")
plt.title("XGBoost Residuals vs Predicted Values")
save_plot("17_xgb_residuals_vs_predicted")

# 18) Residuals by fold
plt.figure(figsize=(9, 5))
fold_data = [
    pred_df.loc[pred_df["fold"] == f, "residual"].clip(-res_clip, res_clip)
    for f in sorted(pred_df["fold"].unique())
]
plt.boxplot(fold_data, labels=sorted(pred_df["fold"].unique()))
plt.xlabel("Fold")
plt.ylabel("Residual")
plt.title("Residual Distribution by Fold")
save_plot("18_xgb_residuals_by_fold")


# =====================================================
# WEEKLY ANALYSIS
# =====================================================

if "week_start" in pred_df.columns:
    pred_df["week_start"] = pd.to_datetime(pred_df["week_start"])

    weekly_compare = (
        pred_df.groupby("week_start")[["real", "pred"]]
        .sum()
        .reset_index()
    )

    weekly_compare["residual"] = weekly_compare["real"] - weekly_compare["pred"]
    weekly_compare["abs_error"] = np.abs(weekly_compare["residual"])

    weekly_compare.to_csv(
        os.path.join(CSV_DIR, "xgb_weekly_actual_vs_predicted.csv"),
        index=False
    )

    # 19) Weekly actual vs predicted
    plt.figure(figsize=(12, 5))
    plt.plot(weekly_compare["week_start"], weekly_compare["real"], label="Actual")
    plt.plot(weekly_compare["week_start"], weekly_compare["pred"], label="Predicted")
    plt.xlabel("Week")
    plt.ylabel("Total Crime Count")
    plt.title("Weekly Actual vs Predicted Crime Counts")
    plt.legend()
    save_plot("19_xgb_weekly_actual_vs_predicted")

    # 20) Weekly error trend
    plt.figure(figsize=(12, 5))
    plt.plot(weekly_compare["week_start"], weekly_compare["abs_error"])
    plt.xlabel("Week")
    plt.ylabel("Absolute Error")
    plt.title("Weekly Absolute Error Trend")
    save_plot("20_xgb_weekly_absolute_error_trend")


# =====================================================
# ERROR BY COUNT GROUP
# =====================================================

pred_df["real_count_group"] = pd.cut(
    pred_df["real"],
    bins=[-0.01, 0, 1, 2, 5, 10, np.inf],
    labels=["0", "1", "2", "3-5", "6-10", "10+"]
)

bucket_analysis = pred_df.groupby("real_count_group", observed=True).agg(
    sample_count=("real", "count"),
    mean_real=("real", "mean"),
    mean_pred=("pred", "mean"),
    mae=("abs_error", "mean"),
    rmse=("residual", lambda x: np.sqrt(np.mean(x ** 2)))
).reset_index()

bucket_analysis.to_csv(
    os.path.join(CSV_DIR, "xgb_error_by_count_group.csv"),
    index=False
)

# 21) MAE by crime count group
plt.figure(figsize=(9, 5))
plt.bar(bucket_analysis["real_count_group"].astype(str), bucket_analysis["mae"])
plt.xlabel("Actual Crime Count Group")
plt.ylabel("MAE")
plt.title("XGBoost Error Analysis by Crime Count Group")
save_plot("21_xgb_error_by_count_group")

# 22) Sample count by group
plt.figure(figsize=(9, 5))
plt.bar(bucket_analysis["real_count_group"].astype(str), bucket_analysis["sample_count"])
plt.xlabel("Actual Crime Count Group")
plt.ylabel("Sample Count")
plt.title("Sample Distribution by Crime Count Group")
save_plot("22_sample_distribution_by_count_group")


# =====================================================
# GRID BASED ERROR ANALYSIS
# =====================================================

if "grid_id" in pred_df.columns:
    grid_error = pred_df.groupby("grid_id").agg(
        sample_count=("real", "count"),
        mean_real=("real", "mean"),
        mean_pred=("pred", "mean"),
        total_real=("real", "sum"),
        total_pred=("pred", "sum"),
        mae=("abs_error", "mean"),
        rmse=("residual", lambda x: np.sqrt(np.mean(x ** 2)))
    ).reset_index()

    grid_error.to_csv(
        os.path.join(CSV_DIR, "xgb_grid_error_analysis.csv"),
        index=False
    )

    top_error_grids = grid_error.sort_values("mae", ascending=False).head(20)

    # 23) Top 20 highest error grids
    plt.figure(figsize=(10, 6))
    plt.barh(top_error_grids["grid_id"].astype(str), top_error_grids["mae"])
    plt.gca().invert_yaxis()
    plt.xlabel("MAE")
    plt.ylabel("Grid ID")
    plt.title("Top 20 Highest Error Grids")
    save_plot("23_top20_highest_error_grids")


# =====================================================
# COUNT BASED RISK LEVEL ANALYSIS
# =====================================================

# Bu kısım sınıflandırma modeli değil.
# Regresyon tahminlerini LOW / MEDIUM / HIGH şeklinde yorumlamak için ek analizdir.

q70 = pred_df["real"].quantile(0.70)
q90 = pred_df["real"].quantile(0.90)

def count_to_risk_level(x):
    if x <= q70:
        return "LOW"
    elif x <= q90:
        return "MEDIUM"
    else:
        return "HIGH"

pred_df["real_risk_level"] = pred_df["real"].apply(count_to_risk_level)
pred_df["pred_risk_level"] = pred_df["pred"].apply(count_to_risk_level)

risk_labels = ["LOW", "MEDIUM", "HIGH"]

risk_cm = confusion_matrix(
    pred_df["real_risk_level"],
    pred_df["pred_risk_level"],
    labels=risk_labels
)

risk_cm_df = pd.DataFrame(
    risk_cm,
    index=[f"Actual_{x}" for x in risk_labels],
    columns=[f"Pred_{x}" for x in risk_labels]
)

risk_cm_df.to_csv(
    os.path.join(CSV_DIR, "xgb_count_based_risk_confusion_matrix.csv")
)

risk_report = classification_report(
    pred_df["real_risk_level"],
    pred_df["pred_risk_level"],
    labels=risk_labels,
    output_dict=True
)

pd.DataFrame(risk_report).T.to_csv(
    os.path.join(CSV_DIR, "xgb_count_based_risk_classification_report.csv")
)

# 24) Risk confusion matrix
plt.figure(figsize=(7, 6))
plt.imshow(risk_cm)
plt.title("Count-Based Risk Level Confusion Matrix")
plt.xlabel("Predicted Risk Level")
plt.ylabel("Actual Risk Level")
plt.xticks(range(len(risk_labels)), risk_labels)
plt.yticks(range(len(risk_labels)), risk_labels)
plt.colorbar(label="Count")

for i in range(len(risk_labels)):
    for j in range(len(risk_labels)):
        plt.text(j, i, risk_cm[i, j], ha="center", va="center")

save_plot("24_count_based_risk_confusion_matrix")


# =====================================================
# FINAL MODEL TRAINING
# =====================================================

print("\n=================================")
print("TRAINING FINAL MODEL")
print("=================================")

final_model = create_xgb_model()
final_model.fit(X, y_diff)

model_path = os.path.join(MODEL_DIR, "crime_xgboost_robust_model.pkl")
joblib.dump(final_model, model_path)

print(f"Model saved successfully -> {model_path}")


# =====================================================
# FEATURE IMPORTANCE
# =====================================================

importance = pd.DataFrame({
    "feature": X.columns,
    "importance": final_model.feature_importances_
})

importance = importance.sort_values("importance", ascending=False)
importance.to_csv(
    os.path.join(CSV_DIR, "xgb_feature_importance.csv"),
    index=False
)

print("\n=================================")
print("TOP 20 REAL FEATURES")
print("=================================")
print(importance.head(20))

# 25) Feature importance
top20 = importance.head(20)

plt.figure(figsize=(10, 8))
plt.barh(top20["feature"], top20["importance"])
plt.gca().invert_yaxis()
plt.title("XGBoost Feature Importance - Stationary Model")
plt.xlabel("Importance Score")
save_plot("25_xgb_feature_importance")

# 26) Top 10 feature distributions
top10_features = importance.head(10)["feature"].tolist()

for idx, feature in enumerate(top10_features, start=1):
    vals = X[feature].replace([np.inf, -np.inf], np.nan).dropna()

    if len(vals) == 0:
        continue

    clip_val = np.percentile(vals, 99)

    plt.figure(figsize=(9, 5))
    plt.hist(vals.clip(vals.min(), clip_val), bins=80)
    plt.xlabel(feature)
    plt.ylabel("Frequency")
    plt.title(f"Distribution of Feature: {feature}")
    save_plot(f"26_{idx:02d}_feature_distribution_{feature}")


# =====================================================
# SAVE FINAL METADATA
# =====================================================

end_time = time.time()
total_minutes = (end_time - START_TIME) / 60

metadata = {
    "target": TARGET,
    "model_type": "XGBRegressor",
    "stationary_target": "target_diff = log1p(total_count) - log1p(rolling_4w_mean)",
    "row_count": int(len(df)),
    "feature_count": int(len(features)),
    "features": features,
    "missing_features": missing_features,
    "cv_results": final_results,
    "risk_thresholds": {
        "q70": float(q70),
        "q90": float(q90)
    },
    "model_path": model_path,
    "output_dir": OUTPUT_DIR,
    "total_runtime_minutes": float(total_minutes)
}

with open(os.path.join(CSV_DIR, "xgb_training_metadata.json"), "w", encoding="utf-8") as f:
    json.dump(metadata, f, ensure_ascii=False, indent=4)

print("\n=================================")
print("ALL DONE")
print("=================================")
print(f"All charts saved under -> {OUTPUT_DIR}")
print(f"All CSV files saved under -> {CSV_DIR}")
print(f"Model saved under -> {model_path}")
print(f"Total runtime: {total_minutes:.2f} minutes")