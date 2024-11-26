from flask import Flask, jsonify, request, make_response
import ifcopenshell
import snowflake.connector
import os
import json
from snowflake.snowpark import Session
import tempfile
import logging
app = Flask(__name__)

@app.route("/load_ifc", methods=["POST"])
def load_ifc(): 
    # this is a very small example of how to load an ifc file
    # and return the number some data
    # For now we are not doing anything with the input data
    # but it can be used to determine which files to read for example

    # Get JSON data from request
    data = request.get_json()

    # Check if the 'data' key exists in the received JSON
    if 'data' not in data:
        return jsonify({'error': 'Missing data key in request'}), 400

    # Extract the 'data' list from the received JSON
    data_list = data['data']

    # Initialize a list to store converted values
    final_data = []

    # Iterate over each item in 'data_list'
    for i, item in enumerate(data_list):
        print("Entering processing " + str(item))    
        logging.debug(f"Processing item {i}: {item}")
        # Load the IFC file with ifcopenshell
        # in this example I am opening the file from the same image
        # but it can be opened from a different location for example an stage
        row_index  = item[0]
        model_name = item[1]
        model = ifcopenshell.open(os.path.join("/opt/models", model_name))

        model_schema = model.schema

        # Example: Retrieve all walls
        walls = [element.GlobalId for element in model.by_type("IfcWall")]
        model_data = {"model_name": model_name, "model_schema": model_schema, "walls": walls}
        final_data.append([i, model_data])
    # Return the converted data as JSON
    response = make_response({"data": final_data})
    response.headers['Content-type'] = 'application/json'    
    return jsonify({'data': final_data})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
