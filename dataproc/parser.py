import csv


MOON_MOTOR_MULTIPLIER = (34*48*2 - 1)/360
EARTH_MOTOR_MULTIPLIER = (34*48 - 1)/360



moon_positions = []
earth_positions = []
def write_year_range(start:int, end:int):
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


    print(f'num moon positions: {len(moon_positions)}')
    print(f'num earth positions: {len(earth_positions)}')


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
    write_year_range(2021, 2021)