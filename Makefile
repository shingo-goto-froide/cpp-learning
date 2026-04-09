CXX      := g++
CXXFLAGS := -std=c++23 -g -fdiagnostics-color=always -Wall -pedantic-errors
PCH_SRC  := all.hpp
PCH_OUT  := all.hpp.gch
TARGET   := main.exe
SRC      := main.cpp

# デフォルトターゲット: PCH → 実行ファイル
all: $(TARGET)

# プリコンパイル済みヘッダーのビルド
$(PCH_OUT): $(PCH_SRC)
	$(CXX) $(CXXFLAGS) -x c++-header $< -o $@

# 実行ファイルのビルド（PCH を include）
$(TARGET): $(SRC) $(PCH_OUT)
	$(CXX) $(CXXFLAGS) -include $(PCH_SRC) $< -o $@

# 実行
run: $(TARGET)
	./$(TARGET)

# 生成ファイルを削除
clean:
	del /Q $(TARGET) $(PCH_OUT) 2>nul || true

.PHONY: all run clean