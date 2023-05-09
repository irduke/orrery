import csv
import requests


MOON_MOTOR_MULTIPLIER = (34*48*2 - 1)/360
EARTH_MOTOR_MULTIPLIER = (34*48 - 1)



moon_positions = []
earth_positions = []
def parse_year_range(start:int, end:int):
    """
    start and end are both inclusive
    """
    prev_day = 400
    with open('database.csv') as file:
        linereader = csv.reader(file, delimiter=',')
        for line in linereader:
            _, year, day, time, moon_pos, earth_pos = line
            
            if prev_day == day:
                continue
            else:
                prev_day = day


            #Skip over column header and any years outside range
            try:
                year = int(year, 2)
            except ValueError:
                continue
            if year < start:
                continue
            elif year > end:
                break
            else:
                #Convert motor positions to int then store in list variable
                moon_val = int(moon_pos, 2)
                moon_val = int(moon_val * MOON_MOTOR_MULTIPLIER)
                earth_val = int(earth_pos, 2)
                earth_val = int(earth_val * EARTH_MOTOR_MULTIPLIER)

                moon_positions.append(str(moon_val))
                earth_positions.append(str(earth_val))


    write_data(earth_positions, moon_positions)


def parse_nasa_horizons(start_date, end_date):
    """
    Grabs data from NASA Horizons db
    Documentation: https://ssd-api.jpl.nasa.gov/doc/horizons.html

    Date format: "YYYY-MM-DD HR:MIN"
    """
    earth_positions = []
    moon_positions = []

    req_url = f"https://ssd.jpl.nasa.gov/api/horizons.api?format=text&COMMAND='301'&MAKE_EPHEM='YES'&EPHEM_TYPE='OBSERVER'&CENTER='780@399'&START_TIME='{start_date}'&STOP_TIME='{end_date}'&STEP_SIZE='60 min'&QUANTITIES='4,7'"
    response = requests.get(req_url).text

    start = "$$SOE"
    end = "$$EOE"

    #Grabs only position data from response, L+outdated API does not have JSON response format
    pos_data = response[response.find(start)+len(start):response.rfind(end)].split("\n")
    pos_data = [x for x in pos_data if x]
    for line in pos_data:
        values = line.split(" ")
        values = [x for x in values if x]
        if len(values) != 7:
            values.pop(2)
        # year_date contains YYYY-Month-DD, elevation is excluded, and sr stands for Sidereal
        year_date, hour, azimuth, _, sr_hour, sr_min, sr_sec = values

        e_motor_pos = (int(sr_hour)*60*60 + int(sr_min)*60 + float(sr_sec)) / 86400 #number of seconds in a day
        e_motor_pos = int(e_motor_pos * EARTH_MOTOR_MULTIPLIER)

        m_motor_pos = int(float(azimuth) * MOON_MOTOR_MULTIPLIER)

        earth_positions.append(str(e_motor_pos))
        moon_positions.append(str(m_motor_pos))

        
    write_data(earth_positions, moon_positions)


 
def write_data(earth_positions:list, moon_positions:list):
    """
    Takes list of earth and moon positions and writes to text file for copy/paste
    Paste list into DAT section of P2 code to write to chip
    """

    with open('earthdata.txt', 'w') as earthdb:
        for i, val in enumerate(earth_positions):
            if i % 500000 == 0 and i != 0:
                earthdb.write("\n"*50)
                earthdb.write(f'{val},')
            if i % 50 == 0 and i != 0:
                earthdb.write("{\n}" + val + ",")
            elif i != len(earth_positions) -1:
                earthdb.write(f'{val},')
            else:
                earthdb.write(val)

    with open('moondata.txt', 'w') as moondb:
        for i, val in enumerate(moon_positions):
            if i % 500000 == 0 and i != 0:
                moondb.write("\n"*50)
                moondb.write(f'{val},')
            elif i % 50 == 0 and i != 0:
                moondb.write("{\n}" + val + ",")
            elif i != len(moon_positions) -1:
                moondb.write(f'{val},')
            else:
                moondb.write(val)


if __name__ == "__main__":
    parse_nasa_horizons("2023-01-01 00:00", "2023-12-31 23:00")