#include "all.hpp"

int main(){
    double height{};
    std::cout << "height(m)>";
    std::cin >> height;

    double mass{};
    std::cout << "mass(kg)";
    std::cin >> mass;

    double bmi = mass / (height * height);

    std::cout << "BMI=" << bmi << "\n"s;
    
}