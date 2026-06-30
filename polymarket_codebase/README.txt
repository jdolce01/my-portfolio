#Arbitrage Exploration and ML Detection

# Overview
This project analyzes market microstructure and inefficiencies in prediction markets using data from the Polmakret API. The goal is to identify near arbitrage inefficiencies in different markets and model these signals with an optimized random tree regressor. 

# Environment: 
Python version: 3.12

## Features
- pulled live data from the api via websockets
- random forest model optimized with grid search
- creation of additional variables like spreads, volatility, imbalance

## Project Structure
- `dolce_julia_final_project_main.ipynb` — main analysis and modeling
- `data/polymarket_microstructure_live.csv` — 
- `data/polymarket_market_universe.csv`     - collected datasets
- `requirements.txt` — dependencies
- `README.txt` - this file

## Setup Instructions

1. Download the project folder

2. Install dependencies 
    pip install -r requirements.txt

3. Run the notebook:
    jupyter notebook
