with open("daylookuptable", "w") as file:
    earth_motor_positions = []
    for i in range(366):
        #motor_pos = min(int(i//0.005569458), 65535)
        motor_pos = min(int(i*126.301369863), 65535)
        earth_motor_positions.append(motor_pos)
        file.write(str(motor_pos))
        if i != 365:
            file.write(",") 
    file.write("\n"*2)
    for i, val in enumerate(earth_motor_positions):
        axial_correction_pos = int(val/28.2642550582)
        file.write(str(axial_correction_pos))
        if i != 365:
            file.write(",")

# 46100-1 -> max for earth arm
# 1632 -> max for axial correction