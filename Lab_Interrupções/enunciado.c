/*Construa um programa que, utilizando interrupções nas chaves da placa (ligadas a PJ0 e PJ1), implemente o seguinte comportamento dos leds do Port N:

Quando o usuário apertar o botão em PJ0, D1 acende e D2 apaga (portanto PJ0 deve ser sensível à borda de descida);
Quando o usuário soltar o botão em PJ1, D1 apaga e D2 acende (portanto PJ1 deve ser sensível à borda de subida).

Ligue o pino PK7 (saída) ao pino PM0 (entrada), utilizando um fio/jumper em uma das barras de pinos, tanto faz se for a de cima (macho) ou a de baixo (fêmea). O loop principal deverá simplesmente ler o pushbutton USR_SW2 e escrever o valor lido em PK7.

Configure uma interrupção por borda de descida no pino PM0. Sempre que a interrupção ocorrer, o led D1 deve trocar de estado.


*/